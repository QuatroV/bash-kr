#! /bin/bash

# Locking the file, so it will be executed only once at the same time
lock_file="./lockfiles/rls1.lock"

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


DirectoryTemp=/tmp/GenTargets
DirectoryTargets="$DirectoryTemp/Targets"
DirectoryDestroy="$DirectoryTemp/Destroy"

# Function to check if a point is in the sector of a circle
# Arguments: center_x, center_y, radius, angle1, angle2, point_x, point_y
function is_point_in_sector() {
  local center_x=$1
  local center_y=$2
  local radius=$3
  local angle1=$4
  local angle2=$5
  local point_x=$6
  local point_y=$7

  # Calculate the distance between the center and the point
  local distance=$(awk -v center_x="$center_x" -v center_y="$center_y" -v point_x="$point_x" -v point_y="$point_y" 'BEGIN{ printf "%.2f", sqrt((point_x - center_x)^2 + (point_y - center_y)^2) }')

  # Calculate the angle between the center and the point in degrees
  local angle=$(awk -v center_x="$center_x" -v center_y="$center_y" -v point_x="$point_x" -v point_y="$point_y" 'BEGIN{ angle = atan2(point_x - center_x, point_y - center_y) * 180 / 3.14159; if (angle < 0) angle += 360; printf "%.2f", angle }')

  # Normalize angles to be between 0 and 360 degrees
  angle1=$(bc <<< "$angle1 % 360")
  angle2=$(bc <<< "$angle2 % 360")
  angle=$(bc <<< "$angle % 360")

  # Handle negative angles
  if [[ $(bc <<< "$angle1 > $angle2") == 1 ]]; then
    if [[ $(bc <<< "$angle < $angle1 && $angle > $angle2") == 1 ]]; then
      # Handle angles in the negative range
      angle=$(bc <<< "$angle + 360")
    fi
  fi

  local condition1=$(bc <<< "$distance <= $radius")
  local condition2=$(bc <<< "$angle >= $angle1")
  local condition3=$(bc <<< "$angle <= $angle2")

  # Check if the point lies within the sector
  if [ $condition1 -eq 1 ] && [ $condition2 -eq 1 ] && [ $condition3 -eq 1 ]; then
    echo "true"
  else
    echo "false"
  fi
}

# Округление дробного числа с отбросом дробной части
function round(){
    res=`awk "BEGIN{print int($1)}"`
    echo $res
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

# Чистим логи
function clear_logs(){
    # Очищаем файл с логами первой засечки
    echo "" > ./temp/rls1_targets_first.log
}

# Определяет, приближается ли цель к точке
# $1, $2 - x, y прошлые координаты цели
# $3, $4 - x, y текущие координаты цели
# $5, $6 - x, y точки 
# Возвращает true/false 
function is_moving_towards() {
  # First pair of coordinates
  local x1=$1
  local y1=$2

  # Second pair of coordinates
  local x2=$3
  local y2=$4

  # Third pair of coordinates
  local x3=$5
  local y3=$6

  # Calculate the distances
  local distance1=$(( (x1 - x3) ** 2 + (y1 - y3) ** 2 ))
  local distance2=$(( (x2 - x3) ** 2 + (y2 - y3) ** 2 ))

  # Compare the distances and return true or false
  if [ $distance2 -lt $distance1 ]; then
    echo "true"
  else
    echo "false"
  fi
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
    rm -rf ./messages/rls1/*
}

SPRO_COORDINATE_X=2500000;
SPRO_COORDINATE_Y=3680000;

RLS1_COORDINATE_X=3136000
RLS1_COORDINATE_Y=3815000
RLS1_RADIUS=4000000
RLS1_ANGLE_START=10
RLS1_ANGLE_END=170

# MAIN CYCLE

clear_logs
clear_messages

while :
do
    sleep 0.5

    # Ответ на проверку на работоспособность
    work_checks=`ls -t ./messages/kp/rls1 2>/dev/null`
    for work_check in $work_checks; do
        encrypted_info=`cat ./messages/kp/rls1/$work_check`
        decrypted_string=$(decipher_string "$encrypted_info" "$PASSPHRASE")
        rm ./messages/kp/rls1/$work_check

        msg="РЛС1 функционирует в нормальном режиме"
        encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

        msg_name=$(generate_random_string)

        echo $encrypted_msg > ./messages/rls1/$msg_name.log
    done

    # Все цели на данном шаге
    targets=`ls -t $DirectoryTargets 2>/dev/null| uniq | head -30 `

    # Бегаем по последним >=30 целям
    for target in $targets ; do

        target_id=${target: -6}
        current_coordinates=`cat $DirectoryTargets/$target`
        current_coordinate_x_str=`cut -d, -f1 <<< $current_coordinates`
        current_coordinate_y_str=`cut -d, -f2 <<< $current_coordinates`
        current_x=${current_coordinate_x_str:1} 
        current_y=${current_coordinate_y_str:1}

        # Arguments: center_x, center_y, radius, angle1, angle2, point_x, point_y
        target_in_area=`is_point_in_sector $RLS1_COORDINATE_X $RLS1_COORDINATE_Y $RLS1_RADIUS $RLS1_ANGLE_START $RLS1_ANGLE_END $current_x $current_y `

        # Если цель вне зоны поражения, то пропускаем итерацию
        if [ $target_in_area == "false" ]; then
            continue
        fi

        # Прошлая цель во первом файле с обнаружением
        previous_string=`grep $target_id ./temp/rls1_targets_first.log`

        if [ -z "$previous_string" ]; then
            # То записываем в конец файла ID цели
            echo "`echo $target | tail -c 7 `,`cat $DirectoryTargets/$target`" >> ./temp/rls1_targets_first.log

            msg="Обнаружена цель ID:$target_id с координатами x:$current_x, y:$current_y"
            encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

            msg_name=$(generate_random_string)

            echo $encrypted_msg > ./messages/rls1/$msg_name.log
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

            is_moving_towards_spro=`is_moving_towards $previous_x $previous_y $current_x $current_y $SPRO_COORDINATE_X $SPRO_COORDINATE_Y`

            # Меняем координаты у ББ для дальнейших вычислений
            previous_string_line_number=`grep -n $target_id ./temp/rls1_targets_first.log`
            new_line="`echo $target | tail -c 7 `,`cat $DirectoryTargets/$target`"
            sed -i "s/$previous_string/$new_line/g" "./temp/rls1_targets_first.log"

            if [ $target_type == 'ballistic_missle' ] && [ $is_moving_towards_spro == 'true' ]; then

                msg="Цель с ID: $target_id (ББ) движется в сторону СПРО"
                encrypted_msg=$(cipher_string "$msg" "$PASSPHRASE")

                msg_name=$(generate_random_string)

                echo $encrypted_msg > ./messages/rls1/$msg_name.log
            fi
        fi

    done
done 



