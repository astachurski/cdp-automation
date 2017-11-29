source authdata
API=https://api.github.com

echo "=================================================================="
echo " Usage:                                                           "
echo " ./cdp-manage-repositories.sh create|remove|activity students-list"
echo " create - create all repositories and configure them              "
echo " remove - removes all repositories                                "
echo " activity - returns date of last commit for each student          "
echo " getpullreqs - returns # of open pull requests for each student   "
echo "                                                                  "
echo " Note: jq parser is needed to obtain activity data                "
echo "=================================================================="
echo

if [ $# -ne 2 ]; then
    echo "illegal number of parameters, exiting..."
    exit
fi

function create_repo(){
    echo "creting repository for: "
    echo "grupa: "  $GROUPNO
    echo "priv: " $PRIV
    echo "repo owner: " $REPOOWNER
    curl -v  \
     -H "Content-Typet: application/json" \
     -H "Authorization: Basic $AUTHSTR" \
     -X POST -d '{"name":"'"$1"'","auto_init":"true","private":'$PRIV'}'  $API/user/repos
}

function  delete_repo(){
    curl -i \
     -H "Content-Typet: application/json" \
     -H "Authorization: Basic $AUTHSTR" \
     -X DELETE \
     $API/repos/$REPOOWNER/$1
}

function  get_activity_for_repo(){
   RESULT=`curl -s \
     -H "Content-Typet: application/json" \
     -H "Authorization: Basic $AUTHSTR" \
     -X GET \
     $API/repos/$REPOOWNER/$1/commits`
   RES=`jq '.[0] | .commit.author.date' <(echo ${RESULT})`
   echo ${RES:1:10}
}

function  get_pullrequests_repo(){
   RESULT=`curl -s \
     -H "Content-Typet: application/json" \
     -H "Authorization: Basic $AUTHSTR" \
     -X GET \
     $API/repos/$REPOOWNER/$1/pulls`

   echo " -----open pull requests:-------- "
   jq '. | length'  <(echo $RESULT)
}

# $1 - reponame
# #2 - branch
function  update_repo_protection(){
    curl -i \
     -H "Content-Typet: application/json" \
     -H "Authorization: Basic $AUTHSTR" \
     -X PUT $API/repos/$REPOOWNER/$1/branches/$2/protection \
     -d @- << EOF \

{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null
}
EOF
    
}


file=$2
echo "parameters passed:"$1,$2

while IFS='' read -r NAME || [[ -n "$line" ]];
do
    read -ra PAIR <<< "$NAME"
    FNAME=${PAIR[0],,}
    LNAME=${PAIR[1],,}
    LNAMESHORT=${LNAME:0:3}
    REPONAME=`iconv -f utf-8 -t ascii//translit <<< $FNAME$LNAMESHORT`
    REPONAMEFULL=$PREFIX-$GROUPNO-$REPONAME
    echo "repository to process: " $REPONAMEFULL
    if [ $1 = "create" ]; then
    	echo "--- creating repository ---"
	create_repo $REPONAMEFULL
	echo "--- configuring master branch ---"
	update_repo_protection $REPONAMEFULL "master"
    fi
    if [ $1 = "remove" ]; then
    	echo "--- removing ---"
	delete_repo $REPONAMEFULL
    fi

    if [ $1 = "update" ]; then
    	echo "--- updating ---"
	update_repo_protection $REPONAMEFULL "master"
    fi

    if [ $1 = "activity" ]; then
    	echo "--- getting actitivy data ---"
	get_activity_for_repo  $REPONAMEFULL 
    fi

    if [ $1 = "getpullreqs" ]; then
    	echo "--- getting pull requests ---"
	get_pullrequests_repo  $REPONAMEFULL 
    fi        
done <"$file"
