export SERVICES_DIR=$(dirname "$0")

# EC2 CLI function
ec2() {
  case "$1" in
    ls)
      aws ec2 describe-instances \
        --query 'Reservations[].Instances[].{id: InstanceId, name: Tags[?Key==`Name`]|[0].Value, state: State.Name}' \
        | jq -r
      ;;

    ls-running)
      aws ec2 describe-instances \
        --filters Name=instance-state-name,Values=running \
        --query 'Reservations[].Instances[].{id: InstanceId, name: Tags[?Key==`Name`]|[0].Value, state: State.Name}' \
        | jq -r
      ;;

    ls-stopped)
      aws ec2 describe-instances \
        --filters Name=instance-state-name,Values=stopped \
        --query 'Reservations[].Instances[].{id: InstanceId, name: Tags[?Key==`Name`]|[0].Value, state: State.Name}' \
        | jq -r
      ;;

    session)
      if [[ $# -lt 2 ]]; then
        echo "Usage: ec2 session <instance-id>"
        return 1
      fi
      aws ssm start-session \
        --target "$2"
      ;;

    run)
      if [[ $# -lt 2 ]]; then
        echo "Usage: ec2 run <instance-id>"
        return 1
      fi
      echo "Starting instance $2..."
      aws ec2 start-instances \
        --instance-ids "$2" \
        --query 'StartingInstances[0].{InstanceId: InstanceId, PreviousState: PreviousState.Name, CurrentState: CurrentState.Name}' \
        --output table
      ;;

    stop)
      if [[ $# -lt 2 ]]; then
        echo "Usage: ec2 stop <instance-id>"
        return 1
      fi
      echo "Stopping instance $2..."
      aws ec2 stop-instances \
        --instance-ids "$2" \
        --query 'StoppingInstances[0].{InstanceId: InstanceId, PreviousState: PreviousState.Name, CurrentState: CurrentState.Name}' \
        --output table
      ;;

    port-forward)
      if [[ $# -lt 4 ]]; then
        echo "Usage: ec2 port-forward <host> <remote-port> <local-port> <instance-id>"
        return 1
      fi
      aws ssm start-session \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "{\"host\":[\"$2\"], \"portNumber\":[\"$3\"], \"localPortNumber\":[\"$4\"]}" \
        --target "$5"
      ;;

    upload)
      if [[ $# -lt 3 ]]; then
        echo "Usage: ec2 upload <instance-id> <local-file> [remote-path] [port]"
        echo ""
        echo "Examples:"
        echo "  ec2 upload i-1234567890abcdef0 /local/file.txt /home/ec2-user/file.txt 8888"
        return 1
      fi

      local instance_id="$2"
      local file_to_send="$3"
      local remote_file_name="$4"
      local port="$5"

      $SERVICES_DIR/_ec2_upload.sh "$instance_id" "$file_to_send" "$remote_file_name" "$port"
      ;;

    *)
      cat << 'EOF'
Usage: ec2 <command> [options]

Commands:
  ls                        List all EC2 instances
  ls-running                List only running EC2 instances
  ls-stopped                List only stopped EC2 instances
  session <instance-id>     Start an SSM session to an instance
  run <instance-id>         Start (run) an EC2 instance
  stop <instance-id>        Stop an EC2 instance
  port-forward <host> <remote-port> <local-port> <instance-id>
                            Forward a port from instance to local machine
  upload <instance-id> <local-file> [remote-path] [port]
                            Upload a file to an instance via SSM

Examples:
  ec2 ls
  ec2 ls-running
  ec2 ls-stopped
  ec2 session i-1234567890abcdef0
  ec2 run i-1234567890abcdef0
  ec2 stop i-1234567890abcdef0
  ec2 port-forward myinstance.123456789012.us-west-2.rds.amazonaws.com 3306 3306 i-1234567890abcdef0
  ec2 upload i-1234567890abcdef0 /local/file.txt /home/ec2-user/file.txt 8888
EOF
      return 1
      ;;
  esac
}
