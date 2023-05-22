#! /bin/bash

# Запускаем генерацию целей в фоне
bash GenTargets.sh &
bash spro.sh &
bash zrdn1.sh &
bash zrdn2.sh &
bash zrdn3.sh &
bash rls1.sh &
bash rls2.sh &
bash rls3.sh &
bash kp.sh &

# Ловим сингнал вывода и уничтожаем бэкграундовые процессы
trap 'kill $(jobs -p)' EXIT

while :
do
    sleep 0.5
done