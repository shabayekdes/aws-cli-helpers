export AWS_HELPERS_DIR=$(dirname "$0")

alias sso_login="aws sso login --profile"
source $AWS_HELPERS_DIR/session.sh
source $AWS_HELPERS_DIR/services/ec2.sh
