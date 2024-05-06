#!/usr/bin/env fish
set CONTENT_DIR $(readlink content)
rm content && cp -r $CONTENT_DIR content && git add . && git commit && rm -rf content && ln -sr $CONTENT_DIR content
