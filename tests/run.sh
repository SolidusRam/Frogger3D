#!/usr/bin/env bash
# Esegue tutti i test headless, più veloci del tempo reale (--fixed-fps).
# Un test fallisce se esce con un codice d'errore o se nel log compare un
# errore di Godot. Uso: tests/run.sh [nome...]   es. tests/run.sh test_river
cd "$(dirname "$0")/.." || exit 1
godot --headless --path . --import > /dev/null 2>&1
tests=("$@")
[ ${#tests[@]} -eq 0 ] && tests=($(ls tests/test_*.gd | xargs -n1 basename | sed 's/\.gd$//'))
failed=0
for name in "${tests[@]}"; do
	log=$(timeout 300 godot --headless --fixed-fps 60 --path . -s "tests/$name.gd" 2>&1)
	code=$?
	errors=$(echo "$log" | grep -E "SCRIPT ERROR|^ERROR:" | sort | uniq -c)
	if [ $code -eq 0 ] && [ -z "$errors" ]; then
		echo "PASSATO  $name"
	else
		failed=$((failed + 1))
		echo "FALLITO  $name (codice $code)"
		echo "$log" | grep -E "FALLITO|SCRIPT ERROR|ERROR:" | head -20 | sed 's/^/    /'
	fi
done
echo
echo "$((${#tests[@]} - failed)) test passati su ${#tests[@]}"
exit $failed
