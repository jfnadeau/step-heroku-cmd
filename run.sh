# Suffix for missing options.
error_suffix='Please add this option to the wercker.yml or add a heroku deployment target on the website which will set these options for you.'
exit_code_push=0
exit_code_run=0

if [ -z "$WERCKER_HEROKU_CMD_KEY"  ]
then
    if [ ! -z "$HEROKU_KEY" ]
    then
        export WERCKER_HEROKU_CMD_KEY="$HEROKU_KEY"
    else
        fail "Missing or empty option heroku_key. $error_suffix"
    fi
fi

if [ -z "$WERCKER_HEROKU_CMD_APP_NAME" ]
then
    if [ ! -z "$HEROKU_APP_NAME" ]
    then
        export WERCKER_HEROKU_CMD_APP_NAME="$HEROKU_APP_NAME"
    else
        fail "Missing or empty option heroku_app_name. $error_suffix"
    fi
fi

if [ -z "$WERCKER_HEROKU_CMD_USER" ]
then
    if [ ! -z "$HEROKU_USER" ]
    then
        export WERCKER_HEROKU_CMD_USER="$HEROKU_USER"
    else
        export WERCKER_HEROKU_CMD_USER="heroku-deploy@wercker.com"
    fi
fi



# Install heroku toolbelt if needed
if ! type heroku &> /dev/null ;
then
    info 'heroku toolbelt not found, starting installing it'

    cd $TMPDIR
    # result=$(sudo wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh)

    sudo apt-get update
    sudo apt-get install -y ruby1.9.1 git-core
    result=$(sudo dpkg -i $WERCKER_STEP_ROOT/foreman-0.60.0.deb $WERCKER_STEP_ROOT/heroku-3.2.0.deb $WERCKER_STEP_ROOT/heroku-toolbelt-3.2.0.deb)

    if [[ $? -ne 0 ]];then
        warning $result
        fail 'heroku toolbelt installation failed';
    else
        info 'finished heroku toolbelt installation';
    fi
else
    info 'heroku toolbelt is available, and will not be installed by this step'
    debug "type heroku: $(type heroku)"
    debug "heroku version: $(heroku --version)"
fi

curl -H "Accept: application/json" -u :$WERCKER_HEROKU_CMD_KEY https://api.heroku.com/apps/$WERCKER_HEROKU_CMD_APP_NAME
echo "machine api.heroku.com" > /home/ubuntu/.netrc
echo "  login $WERCKER_HEROKU_CMD_USER" >> /home/ubuntu/.netrc
echo "  password $WERCKER_HEROKU_CMD_KEY" >> /home/ubuntu/.netrc
chmod 0600 /home/ubuntu/.netrc
git config --global user.name "$WERCKER_HEROKU_CMD_USER"
git config --global user.email "$WERCKER_HEROKU_CMD_USER"
cd
mkdir -p key
chmod 0700 ./key
cd key

if [ -n "$WERCKER_HEROKU_CMD_KEY_NAME" ]
then
    debug "will use specified key in key-name option: $WERCKER_HEROKU_CMD_KEY_NAME"

    export key_file_name="$WERCKER_HEROKU_CMD_KEY_NAME"
    export privateKey=$(eval echo "\$${WERCKER_HEROKU_CMD_KEY_NAME}_PRIVATE")

    if [ ! -n "$privateKey" ]
    then
        fail 'Missing key error. The key-name is specified, but no key with this name could be found. Make sure you generated an key, *and* exported it as an environment variable.'
    fi

    debug "Writing key file to $key_file_name"
    echo -e "$privateKey" > $key_file_name
    chmod 0600 "$key_file_name"

fi

echo "ssh -e none -i \"/home/ubuntu/key/$key_file_name\" -o \"StrictHostKeyChecking no\" \$@" > gitssh
chmod 0700 /home/ubuntu/key/gitssh
export GIT_SSH=/home/ubuntu/key/gitssh

heroku version


if [ -n "$WERCKER_HEROKU_CMD_RUN" ]
then
    run_command="$WERCKER_HEROKU_CMD_RUN"

    debug "starting heroku $run_command"
    heroku $run_command --app $HEROKU_APP_NAME
    exit_code_run=$?
fi

# Validate git run
if [ $exit_code_run -ne 0 ]
then
    fail 'heroku run failed'
fi

# Validate git push deploy
if [ $exit_code_push -eq 0 ]
then
    success 'deployment to heroku finished successfully'
else
    fail 'git push to heroku failed'
fi
