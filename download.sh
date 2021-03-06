#!/bin/bash

function die()
{
	echo "$*" >&2
	exit 1
}

function refresh()
{
	rm -fr www.henryklahola.nazory.cz
	httrack --do-not-log --mirror --update --store-all-in-cache -O recent,cache \
		--footer "<!-- Mirrored from %s%s -->" \
		http://www.henryklahola.nazory.cz \
		'-*' +'www.henryklahola.nazory.cz/*.htm' +'www.henryklahola.nazory.cz/*.html' \
		2>&1 | egrep -v '^(Done\.|Thanks for using HTTrack!)$'
	[ ${PIPESTATUS[0]} -eq 0 ] || die "can't download"
	cp -R recent/www.henryklahola.nazory.cz www.henryklahola.nazory.cz
	find www.henryklahola.nazory.cz -name '*.tmp' -exec rm '{}' \;
}

[ "$1" == "--force" ] && FORCE=1

. ${0%/*}/conf/config.sh
cd $REPODIR

curl --head http://www.henryklahola.nazory.cz/ 2>/dev/null | grep ^ETag: > etag.new
etag_changed=$(diff etag etag.new 2>&1 | wc -l)
mv etag.new etag

if [ ! "$FORCE" -a "$etag_changed" -eq 0 ]
then
	exit 0
fi

refresh

# do source sanitization
find www.henryklahola.nazory.cz -type f -print0 | xargs -0 python nowz.py
if [ -f www.henryklahola.nazory.cz/Poradi.html ]; then
	c='s/src="[^"]\+"/src=""/'
	sed -i "235${c};253${c}" www.henryklahola.nazory.cz/Poradi.html
fi

# commit part
[ "$1" = "-r" ] && exit 0

git add www.henryklahola.nazory.cz

diff="$(mktemp)"
echo "automatic update:" > "${diff}"
git diff --cached --no-color --stat >> "${diff}"
git commit --quiet --all --file "${diff}"
rm -f "${diff}"
git push origin master >/dev/null 2>&1 || die "unable to push"
