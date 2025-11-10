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

    session)
      if [[ $# -lt 2 ]]; then
        echo "Usage: ec2 session <instance-id>"
        return 1
      fi
      aws ssm start-session \
        --document-name SSM-SessionManagerRunShell \
        --target "$2"
      ;;

    port-forward)
      if [[ $# -lt 4 ]]; then
        echo "Usage: ec2 port-forward <remote-port> <local-port> <instance-id>"
        return 1
      fi
      aws ssm start-session \
        --document-name AWS-StartPortForwardingSession \
        --parameters "{\"portNumber\":[\"$2\"], \"localPortNumber\":[\"$3\"]}" \
        --target "$4"
      ;;

    *)
      echo "Usage: ec2 {ls|ls-running|session <instance-id>|port-forward <remote-port> <local-port> <instance-id>}"
      return 1
      ;;
  esac
}
