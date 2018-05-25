filename=chaos_package.zip

install-lib :
	pip install -r requirements.txt -t ./.tmp

run : install-lib
	(cd .tmp/ && zip -r ../$(filename) ./*) && (zip $(filename) chaos.py)

clean :
	(rm -rf .tmp > /dev/null 2>&1; rm *.zip > /dev/null 2>&1) || echo "clean done"

.PHONY: install-lib run clean