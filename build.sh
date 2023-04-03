#!/bin/sh

if test ! -d ./test; then rm -r ./dist; fi
mkdir dist
./ssg ./src ./dist "karudo's nerd shit" "https://itskarudo.github.io"
