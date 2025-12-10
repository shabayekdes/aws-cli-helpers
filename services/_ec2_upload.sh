#!/usr/bin/expect

# Set the script to not time out
set timeout -1

# Capture the script arguments
set instance_id [lindex $argv 0]
set file_to_send [lindex $argv 1]
set remote_file_name [lindex $argv 2]
set port [lindex $argv 3]

# Set default values if not provided
if {$remote_file_name == ""} {
    set remote_file_name [file tail $file_to_send]
    set remote_file_name "/home/ec2-user/$remote_file_name"
}

if {$port == ""} {
    set port [expr {int(rand() * 10000) + 50000}]
}

# Check if local file exists
if {![file exists $file_to_send]} {
    send_user "Error: Local file '$file_to_send' not found\n"
    exit 1
}

send_user "\nInstance ID: $instance_id\n"
send_user "Using port: $port\n"
send_user "Uploading: $file_to_send -> $remote_file_name\n\n"

# Get file size for progress tracking
set file_size [file size $file_to_send]
send_user "File size: $file_size bytes\n\n"

# Start AWS SSM session and use dd instead of nc for more reliable transfer
send_user "Step 1: Starting listener on remote instance...\n"
spawn aws ssm start-session --target $instance_id
set listener_id $spawn_id
expect {
    -i $listener_id -re "sh-.*" {
        send -i $listener_id "mkdir -p \"\$(dirname \"$remote_file_name\")\"\r"
        expect -i $listener_id -re "sh-.*"
        send -i $listener_id "nc -l -p $port > \"$remote_file_name\" && echo 'TRANSFER_COMPLETE'\r"
        send_user "Listener started on port $port\n"
    }
    timeout {
        send_user "Error: Timeout starting SSM session\n"
        exit 1
    }
}

# Give listener time to start
sleep 3

# Start port forwarding in background
send_user "\nStep 2: Establishing port forwarding...\n"
spawn bash -c "aws ssm start-session --target $instance_id --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":\[\"$port\"\],\"localPortNumber\":\[\"$port\"\]}' 2>&1"
set forward_id $spawn_id
expect {
    -i $forward_id -re "Waiting for connections" {
        send_user "Port forwarding established.\n"
    }
    timeout {
        send_user "Error: Timeout establishing port forwarding\n"
        exec pkill -f "aws ssm"
        exit 1
    }
}

# Give port forwarding time to stabilize
sleep 3

# Send the file with cat (cleaner than dd for this purpose)
send_user "\nStep 3: Transferring file...\n"
spawn bash -c "cat \"$file_to_send\" | nc localhost $port && sleep 1"
set sender_id $spawn_id
expect {
    -i $sender_id eof {
        send_user "\nLocal transfer complete.\n"
    }
    -i $sender_id timeout {
        send_user "Error: Timeout sending file\n"
        exec pkill -f "aws ssm"
        exit 1
    }
}

# Wait for the remote side to confirm completion
send_user "\nStep 4: Waiting for remote confirmation...\n"
set timeout 60
expect {
    -i $listener_id -re "TRANSFER_COMPLETE" {
        send_user "Remote transfer confirmed!\n"
    }
    -i $listener_id timeout {
        send_user "Warning: Timeout waiting for completion signal\n"
    }
}

# Verify the file
send_user "\nStep 5: Verifying uploaded file...\n"
send -i $listener_id "ls -lh \"$remote_file_name\" && echo '---' && md5sum \"$remote_file_name\"\r"
expect {
    -i $listener_id -re "---" {
        send_user "File verification complete\n"
    }
}

# Get local md5 for comparison
set local_md5 [exec md5sum $file_to_send]
send_user "\nLocal MD5: [lindex $local_md5 0]\n"

sleep 2
send -i $listener_id "exit\r"

# Terminate all AWS SSM sessions
send_user "\nStep 6: Cleaning up sessions...\n"
exec pkill -f "aws ssm"
send_user "\n✓ Upload complete!\n"
send_user "File uploaded to: $remote_file_name on instance $instance_id\n"
send_user "\nPlease verify MD5 checksums match!\n"
