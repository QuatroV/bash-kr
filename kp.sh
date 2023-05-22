#! /bin/bash

# Locking the file, so it will be executed only once at the same time
lock_file="./lockfiles/kp.lock"

# Check if the lock file exists
if [ -f "$lock_file" ]; then
    echo "Script is already running or has already been executed."
    exit 0
fi

# Create the lock file
touch "$lock_file"

function on_exit(){
    rm "$lock_file"
}

trap on_exit EXIT

# Actual code

PASSPHRASE="VERY_SECRET"

# Generate a unique random string using uuidgen
function generate_random_string() {
  local random_string=$(uuidgen | tr -d '-')
  echo "$random_string"
}

# Cypher string
function cipher_string() {
  local plaintext="$1"
  local passphrase="$2"
  
  local encrypted_string=$(echo "$plaintext" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -pass pass:"$passphrase")
  echo "$encrypted_string"
}

function decipher_string() {
  local encrypted_string="$1"
  local passphrase="$2"
  
  local decrypted_string=$(echo "$encrypted_string" | openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -pass pass:"$passphrase")
  echo "$decrypted_string"
}

# $1 - от кого сообщение
# $2 - сообщение
function write_logs(){
    local sender=$1
    local msg=$2

    echo "`date` $sender : $msg" >> "./logs/kp.log"

    created_at=$(date +"%Y-%m-%d %H:%M:%S")
    updated_at=$(date +"%Y-%m-%d %H:%M:%S")

    sqlite3 ./db/kp_vko.db "
    INSERT INTO journal (unit, message, created_at, updated_at)
    VALUES ('$sender', '$msg', '$created_at', '$updated_at');
    "        
}

function clear_logs(){
    rm ./logs/kp.log 2>/dev/null

    sqlite3 ./db/kp_vko.db "
    DELETE FROM journal
    " 
}

WORK_CHECK_COUNTER=0;

# MAIN CYCLE

clear_logs

while :
do
    sleep 0.5

    # WORK CHECK

    ((++WORK_CHECK_COUNTER))

    if [ $WORK_CHECK_COUNTER == 20 ]; then
        # Check RLS1
        msg="Проверка работоспособности РЛС 1, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/rls1/$msg_name.log

        # Check RLS2
        msg="Проверка работоспособности РЛС 2, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/rls2/$msg_name.log

        # Check RLS3
        msg="Проверка работоспособности РЛС 3, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/rls3/$msg_name.log

        # Check SPRO
        msg="Проверка работоспособности СПРО, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/spro/$msg_name.log

        # Check ZRDN1
        msg="Проверка работоспособности ЗРДН1, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/zrdn1/$msg_name.log

        # Check ZRDN2
        msg="Проверка работоспособности ЗРДН2, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/zrdn2/$msg_name.log

        # Check ZRDN3
        msg="Проверка работоспособности ЗРДН3, ответьте"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/kp/zrdn3/$msg_name.log
        
        # Clear counter
        WORK_CHECK_COUNTER=0
    fi

    # RLS1

    rls1_messages=`ls -t ./messages/rls1 2>/dev/null`

    for message in $rls1_messages; do
        encrypted_info=`cat ./messages/rls1/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/rls1/$message

        write_logs RLS1 "$decrypted_string"
    done

    # RLS2

    rls2_messages=`ls -t ./messages/rls2 2>/dev/null`

    for message in $rls2_messages; do
        encrypted_info=`cat ./messages/rls2/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/rls2/$message

        write_logs RLS2 "$decrypted_string"
    done

    # RLS3

    rls3_messages=`ls -t ./messages/rls3 2>/dev/null`

    for message in $rls3_messages; do
        encrypted_info=`cat ./messages/rls3/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/rls3/$message

        write_logs RLS3 "$decrypted_string"
    done

    # SPRO

    spro_messages=`ls -t ./messages/spro 2>/dev/null`

    for message in $spro_messages; do
        encrypted_info=`cat ./messages/spro/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/spro/$message

        write_logs SPRO "$decrypted_string"
    done

    # ZRDN1

    zrdn1_messages=`ls -t ./messages/zrdn1 2>/dev/null`

    for message in $zrdn1_messages; do
        encrypted_info=`cat ./messages/zrdn1/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/zrdn1/$message

        write_logs ZRDN1 "$decrypted_string"
    done

    # ZRDN2

    zrdn2_messages=`ls -t ./messages/zrdn2 2>/dev/null`

    for message in $zrdn2_messages; do
        encrypted_info=`cat ./messages/zrdn2/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/zrdn2/$message

        write_logs ZRDN2 "$decrypted_string"
    done

    # ZRDN3

    zrdn3_messages=`ls -t ./messages/zrdn3 2>/dev/null`

    for message in $zrdn3_messages; do
        encrypted_info=`cat ./messages/zrdn3/$message`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/zrdn3/$message

        write_logs ZRDN3 "$decrypted_string"
    done
done