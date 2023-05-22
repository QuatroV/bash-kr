#! /bin/bash

# Locking the file, so it will be executed only once at the same time
lock_file="./lockfiles/zrdn2.lock"

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

DirectoryTemp=/tmp/GenTargets
DirectoryTargets="$DirectoryTemp/Targets"
DirectoryDestroy="$DirectoryTemp/Destroy"

# Округление дробного числа с отбросом дробной части
function round(){
    res=`awk "BEGIN{print int($1)}"`
    echo $res
}

# Определяет, лежит ли точка в окружности
# $1, $2 - x, y центра окружности
# $3, $4 - x, y точки
# $5 - радиус окружности
# Возвращает 1, если в окружности, 0 - иначе
function is_point_in_circle() {
    echo $(((($3 - $1)**2) + (($4 - $2)**2) <= $5**2 ))
}

# Определяет скорость цели по двум координатам
# $1, $2 - x, y первой точки
# $3, $4 - x, y второй точки
# Возвращает скорость цели
function calc_speed(){
    echo `echo "sqrt(($1-$3)^2+($2-$4)^2)" |bc -l`
}

BALLISTIC_MISSLE_MIN_SPEED=8000;
BALLISTIC_MISSLE_MAX_SPEED=10000;
CRUISE_MISSLE_MIN_SPEED=250;
CRUISE_MISSLE_MAX_SPEED=1000;
AIRPLANE_MIN_SPEED=50;
AIRPLANE_MAX_SPEED=250;

# Определяет по скорости цели ее тип
# $1 - скорость цели
# Возвращает "ballistic_missle", "cruise_missle",  "airplane" или "error", если лиапазон скорости не попадает под заданные
function get_target_type(){
    if [ $1 -gt $BALLISTIC_MISSLE_MIN_SPEED ] && [ $1 -lt $BALLISTIC_MISSLE_MAX_SPEED ]; then
        echo "ballistic_missle"
        return
    fi
    if [ $1 -gt $CRUISE_MISSLE_MIN_SPEED ] && [ $1 -lt $CRUISE_MISSLE_MAX_SPEED ]; then
        echo "cruise_missle"
        return
    fi
    if [ $1 -gt $AIRPLANE_MIN_SPEED ] && [ $1 -lt $AIRPLANE_MAX_SPEED ]; then
        echo "airplane"
        return
    fi
    echo "error"
}

ZRDN2_AMMO_AMOUNT=20

# Уничтожение цели
# $1 - ID цели
function destroy_target(){
    echo "" > $DirectoryDestroy/$1
    ((--ZRDN2_AMMO_AMOUNT))
}

# Удаление информации о цели после ее пропажи из первого лога
# $1 - ID цели
function forget_target_first(){
    sed -i --silent "/^$1/d" ./temp/zrdn2_targets_first.log 
}

# Удаление информации о цели после ее пропажи из второго лога
# $1 - ID цели
function forget_target_second(){
    sed -i --silent "/^$1/d" ./temp/zrdn2_targets_second.log 
}

# Чистим логи
function clear_logs(){
    # Очищаем файл с логами первой засечки
    echo "" > ./temp/zrdn2_targets_first.log 
    # Очищаем файл с логами второй засечки
    echo "" > ./temp/zrdn2_targets_second.log 
}

# Получить строку из айдишников из строки с названиями файлов
function get_targets_ids(){
    local input_string="$1"
    local output_string=""

    read -ra words <<< $1

    for word in $1; do
        id="${word: -6}"

        output_string+=" $id"
    done

    echo $output_string
}

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

function clear_messages(){
    rm -rf ./messages/zrdn2/*
}

ZRDN2_COORDINATE_X=2680000;
ZRDN2_COORDINATE_Y=2860000;
ZRDN2_RADIUS=400000;

# MAIN CYCLE

clear_logs

while :
do
    sleep 0.5

    # Ответ на проверку на работоспособность
    work_checks=`ls -t ./messages/kp/zrdn2 2>/dev/null`
    for work_check in $work_checks; do
        encrypted_info=`cat ./messages/kp/zrdn2/$work_check`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/kp/zrdn2/$work_check

        msg="ЗРДН2 функционирует в нормальном режиме"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/zrdn2/$msg_name.log
    done

    # Все цели на данном шаге
    targets=`ls -t $DirectoryTargets 2>/dev/null| uniq | head -30 `

    targets_ids=`get_targets_ids "$targets"`

    # Пробегаем по целям, обнаруженным на прошлом шаге
    prev_targets=`cat ./temp/zrdn2_targets_first.log | cut -d, -f1`

    # Пробегаем по целям, обнаруженным на прошлом шаге
    prev_prev_targets=`cat ./temp/zrdn2_targets_second.log | cut -d, -f1`

    for prev_target in $prev_prev_targets ; do
        current_target_candidate=`grep $prev_target $targets_ids 2>/dev/null`
        prev_target_id=${prev_target: -6}

        # Если в текущем наборе целей есть нет цели с прошлого шага - пишем, что она была сбита
        if [ -z $current_target_candidate ]; then  
            msg="Цель с ID: $prev_target_id была сбита"

            encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

            msg_name=$(generate_random_string)

            echo $encrypted_msg > ./messages/zrdn2/$msg_name.log  

            forget_target_second $prev_target_id
        fi
    done 

    # Бегаем по последним >=30 целям
    for target in $targets ; do

        target_id=${target: -6}
        current_coordinates=`cat $DirectoryTargets/$target`
        current_coordinate_x_str=`cut -d, -f1 <<< $current_coordinates`
        current_coordinate_y_str=`cut -d, -f2 <<< $current_coordinates`
        current_x=${current_coordinate_x_str:1} 
        current_y=${current_coordinate_y_str:1}

        target_in_area=`is_point_in_circle $ZRDN2_COORDINATE_X $ZRDN2_COORDINATE_Y $current_x $current_y $ZRDN2_RADIUS`

        # Если цель вне зоны поражения, то пропускаем итерацию
        if [ ! $target_in_area ]; then
            continue
        fi

        if [ $ZRDN2_AMMO_AMOUNT -gt 0 ]; then
            has_ammo=true
        else
            has_ammo=false
            if [ $ZRDN2_AMMO_AMOUNT -eq 0 ]; then
                ((--ZRDN2_AMMO_AMOUNT))
                msg="Кончились боеприпасы. Переход в режим наблюдения"
                encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

                msg_name=$(generate_random_string)

                echo $encrypted_msg > ./messages/zrdn2/$msg_name.log  
            fi
        fi

        # Если по цели уже стреляли - пишем, что она не была уничтожена и производим повторный выстрел
        previous_previous_string=`grep $target_id ./temp/zrdn2_targets_second.log`
        prev_prev_target_id=${previous_previous_string: -6}

         if [ ! -z $prev_prev_target_id ] && $has_ammo; then  
            msg="Цель с ID: $prev_prev_target_id не была сбита. Производится повторный выстрел"
            encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

            msg_name=$(generate_random_string)

            echo $encrypted_msg > ./messages/zrdn2/$msg_name.log 

            destroy_target $prev_prev_target_id
            continue
        fi

        # Прошлая цель во первом файле с обнаружением
        previous_string=`grep $target_id ./temp/zrdn2_targets_first.log`

        # Если НЕ нашлась строка с таким ID на первой засечке
        if [ -z "$previous_string" ]; then
            # То записываем в конец файла ID цели
            echo "`echo $target | tail -c 7 `,`cat $DirectoryTargets/$target`" >> ./temp/zrdn2_targets_first.log
        else
            # Если нашлась строка на первой засечке
            previous_coordinates=`cut -d, -f 2-3 <<< $previous_string`
            previous_coordinate_x_str=`cut -d, -f1 <<< $previous_coordinates`
            previous_coordinate_y_str=`cut -d, -f2 <<< $previous_coordinates`
            previous_x=${previous_coordinate_x_str:1} 
            previous_y=${previous_coordinate_y_str:1}

            speed=`calc_speed $current_x $current_y $previous_x $previous_y`
            rounded_speed=`round $speed` 

            target_type=`get_target_type $rounded_speed`

            if [ $target_type == "cruise_missle" ] && $has_ammo; then
                msg="Обнаружена крылатая ракета на координатах x:$current_x, y:$current_y. Производится выстрел."
                encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

                msg_name=$(generate_random_string)

                echo $encrypted_msg > ./messages/zrdn2/$msg_name.log 

                # Пишем в файл со целями, по которым стреляли и стреляем по цели
                echo "`echo $target | tail -c 7 `,`cat $DirectoryTargets/$target`" >> ./temp/zrdn2_targets_second.log

                # Убираем цель из первого файла
                forget_target_first $target_id

                # Уничтожаем цель 
                destroy_target $target_id

                continue
            fi

            if [ $target_type == "airplane" ] && $has_ammo; then
                msg="Обнаружен самолет на координатах x:$current_x, y:$current_y. Производится выстрел."
                encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

                msg_name=$(generate_random_string)

                echo $encrypted_msg > ./messages/zrdn2/$msg_name.log 

                # Пишем в файл со целями, по которым стреляли и стреляем по цели
                echo "`echo $target | tail -c 7 `,`cat $DirectoryTargets/$target`" >> ./temp/zrdn2_targets_second.log

                # Убираем цель из первого файла
                forget_target_first $target_id

                # Уничтожаем цель 
                destroy_target $target_id
            fi
        fi    
    done
done