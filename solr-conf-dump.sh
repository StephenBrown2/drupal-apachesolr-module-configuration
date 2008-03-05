solr1='1.4';
solr3='3.x';
solr4='4.x';
destrepo=$(pwd);
sourcerepo="$(cd .. && pwd)/apachesolr-module";
remoterepo="http://git.drupal.org/project/apachesolr.git";

###
# Get the tags, sorted by date
###
git_tags() {
    r=${1-''};
    for tag in $(git tag); do
        hash=$(git rev-parse --verify $tag^{commit});
        date=$(git show --pretty="%ai" ${hash} | head -n1);
        echo ${date} ${tag};
    done | sort ${r} | awk '{print $4}'
}

###
# Get the tags and dates, sorted by date
###
git_tags_dates() {
    r=${1-''};
    for tag in $(git tag); do
        hash=$(git rev-parse --verify $tag^{commit});
        date=$(git show --pretty="%ai" ${hash} | head -n1);
        echo ${date} ${tag};
    done | sort ${r} | awk '{print $1,$4}'
}

###
# Get the latest 10 tags and dates, sorted by date
###
git_tags_latest() {
    r=${1-''};
    late='tail';
    [ "$1" == "-r" ] && late='head';
    for tag in $(git tag); do
        hash=$(git rev-parse --verify $tag^{commit});
        date=$(git show --pretty="%ai" ${hash} | head -n1);
        echo ${date} ${tag};
    done | sort ${r} | awk '{print $4}' | ${late}
}

git_annotated_tags() {
    r=${1-''};
    [ "${r}" != '' ] && r='-';
    git for-each-ref --format="%(taggerdate:iso8601) %(refname:short)" \
    --sort=${r}taggerdate refs/tags | awk '{print $4}';
}

complicated_transfer() {
    ext=$1; shift;
    for file in "$@";
    do
        if [ -d ${sourcerepo}/solr-conf ];
        then
            if [ -f ${sourcerepo}/solr-conf/${file}.${ext} ];
            then
                if [ ! -d ${destrepo}/solr-${solr1} ];
                then
                    mkdir -p ${destrepo}/solr-${solr1};
                fi;
                cp -f ${sourcerepo}/solr-conf/${file}.${ext} ${destrepo}/solr-${solr1}/;
            fi;

            if [ -f ${sourcerepo}/solr-conf/${file}-solr3x.${ext} ];
            then
                if [ ! -d ${destrepo}/solr-${solr3} ];
                then
                    mkdir -p ${destrepo}/solr-${solr3};
                fi;
                cp -f ${sourcerepo}/solr-conf/${file}-solr3x.${ext} ${destrepo}/solr-${solr3}/${file}.${ext};
            elif [ "$(ls ${sourcerepo}/solr-conf/*-solr3x.* 2>/dev/null | wc -l)" != "0" ];
            then
                if [ ! -d ${destrepo}/solr-${solr3} ];
                then
                    mkdir -p ${destrepo}/solr-${solr3};
                fi;
                cp -f ${sourcerepo}/solr-conf/${file}.${ext} ${destrepo}/solr-${solr3}/;
            fi;
        else
            if [ -f ${sourcerepo}/${file}.${ext} ];
            then
                if [ ! -d ${destrepo}/solr-${solr1} ];
                then
                    mkdir -p ${destrepo}/solr-${solr1};
                fi;
                cp -f ${sourcerepo}/${file}.${ext} ${destrepo}/solr-${solr1}/;
            fi;

            if [ -f ${sourcerepo}/${file}-solr3x.${ext} ];
            then
                if [ ! -d ${destrepo}/solr-${solr3} ];
                then
                    mkdir -p ${destrepo}/solr-${solr3};
                fi;
                cp -f ${sourcerepo}/${file}-solr3x.${ext} ${destrepo}/solr-${solr3}/${file}.${ext};
            elif [ "$(ls ${sourcerepo}/*-solr3x.* 2>/dev/null | wc -l)" != "0" ];
            then
                if [ ! -d ${destrepo}/solr-${solr3} ];
                then
                    mkdir -p ${destrepo}/solr-${solr3};
                fi;
                cp -f ${sourcerepo}/${file}.${ext} ${destrepo}/solr-${solr3}/;
            fi;
        fi;
    done;
}

cd ~;
if [ -d ${sourcerepo} ];
then
    echo "${sourcerepo} exists! Verifying legitimacy.";
    cd ${sourcerepo};
    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" &&
        "$(git remote -v | grep fetch | awk '{print $2}')" == "${remoterepo}" ]];
    then
        echo "Verily, it hath the seeming of legitimacy.";
    else
        echo "This is not the repository we are looking for. Move along.";
        exit;
    fi;
else
    echo "${sourcerepo} does not exist. Cloning repository.";
    git clone ${remoterepo} ${sourcerepo};
fi;

cd ${sourcerepo} || exit;
git fetch;
sourcetags=$(git_tags); # Tags were not annotated in the drush repository until 7.x-1.0-beta4
cd ${destrepo} || exit;
#git pull;
desttags=$(git_annotated_tags); # All our tags must be annotated because sometimes nothing changed between versions
tags=$(diff <(echo "${sourcetags}") <(echo "${desttags}") | egrep '(<)' | sed -e 's/[| <]//g');

if [[ ${tags} == '' ]];
then
    echo "Looks like everything's up to date!";
    exit;
fi;

echo -e "--- SOURCE vs DEST tags ---";
echo $tags;

cd ${sourcerepo};
pwd;
for tag in $tags; do
    cd ${destrepo};
    destdate=$(git show --pretty="%ai" | head -1);
    desttag=$(git describe --abbrev=0 --tags);
    cd ${sourcerepo};
    echo;
    echo "Checking out $tag";
    git checkout $tag;
    date=$(git show --pretty="%ai" | head -1);
    if [[ "${date}" < "${destdate}" || "${date}" == "${destdate}" ]];
    then
        echo;
        # echo "${destdate} is newer than or the same as ${date}";
        echo "Current tag '${desttag}' is newer than or the same as '${tag}'";
        echo "Skipping ${tag}";
        continue;
    fi;
    echo;
    echo "Git status:";
    git status;
    echo;
    echo "Removing ${destrepo}/solr-[0-9]*";
    rm -rf ${destrepo}/solr-[0-9]*;
    echo;
    if [ ! -d ${sourcerepo}/solr-conf/solr-1.4 ];
    then
        if [ ! -d ${sourcerepo}/solr-conf ];
        then
            echo;
            echo "${sourcerepo}/solr-conf dir not found!";
            echo ${sourcerepo};
            ls ${sourcerepo};
        elif [ ! -d ${sourcerepo}/solr-conf/solr-3.x ];
        then
            echo;
            echo "${sourcerepo}/solr-conf dir not organized!";
            echo ${sourcerepo}/solr-conf;
            ls ${sourcerepo}/solr-conf;
        fi;
        echo;
        echo "Running complicated transfer.";
        complicated_transfer xml schema solrconfig;
        complicated_transfer txt protwords;
    else
        echo ${sourcerepo}/solr-conf;
        ls ${sourcerepo}/solr-conf;
        echo;
        echo "Copying ${sourcerepo}/solr-conf/ to ${destrepo}/";
        cp -r ${sourcerepo}/solr-conf/* ${destrepo}/;
    fi;
    cd ${destrepo}/ && echo && pwd;
    echo && git diff --stat &&
    git add -A &&
    git commit -am "apachesolr module v${tag}" --date="${date}";
    GIT_COMMITTER_DATE="${date}" git tag -a ${tag} -m "apachesolr-${tag}" &&
    echo && echo "Latest git tags:" &&
    git_annotated_tags | tail &&
    echo && tree && echo && git log -1;
    echo;
    [ -d solr-3.x ] && diff -qr solr-1.4 solr-3.x;
    echo;
    [ -d solr-3.x -a -d solr-4.x ] && diff -qr solr-3.x solr-4.x;
    #read -p "Pausing... Press [Enter] to continue.";
    sleep 2;
    echo;
done;
cd
