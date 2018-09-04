#!/bin/bash
PERL=`which perl`
GIT=`which git`
while [[ $# -gt 1 ]]
do
    key="$1"

    case $key in
        -f|--find)
            FIND="$2"
            shift # past argument
            ;;
        -r|--replace-with)
            REPLACE_WITH="$2"
            shift # past argument
            ;;
        -s|--sub-dir)
            SUB_DIR="$2"
            shift # past argument
            ;;
        #        -c|--config)
            #            CONFIG="$2"
            #            shift # past argument
            #            ;;
        *)
            # unknown option
            ;;
    esac
    shift # past argument or value
done

findAndReplace()
{
    if [ ! -z "$2" -a "$2" = "1" ]; then
        FIND="\\b${FIND}\\b"
    fi
    if [ "$FIND" = "mysql_select_db" -a "$REPLACE_WITH" = "mysqli_select_db" ];then
        fixMysqlSelectDb "$1"
    elif [ "$FIND" = "mysql_query" -a "$REPLACE_WITH" = "mysqli_query" ];then
        fixMysqlQuery "$1"
    else
        echo $(sed -i "s/\b${FIND}\b/${REPLACE_WITH}/g" $1)
    fi
}

fixMysqlSelectDb()
{
    echo $($PERL -pi -e 's/mysql_select_db\(([^,]+), ?([^)]+)\)/mysqli_select_db($2, $1)/g' $1)
}

fixMysqlQuery()
{
    echo $($PERL -pi -e 's/mysql_query\(([^,]+), ?([^)]+)\)/mysqli_query($2, $1)/g' $1)
}

CPWD=`pwd`
USER_SRC=${CPWD}/

if [ -z "$CONFIG" -a -z "$FIND" ]; then
    echo "Pattern FIND in missing: -f <FIND>..."
    exit 0
fi

if [ -z "$CONFIG" -a -z "$REPLACE_WITH" ]; then
    echo "Pattern REPLACE_WITH in missing: -r <FIND>..."
    exit 0
fi

if [ -z "$SUB_DIR" ]; then
    echo "To fix just for specificaly folder, use: -s <DIR> | --sub-dir <DIR>"
    read -p "Do you really want a fix for the 'WHOLE SYSTEM'? (Y/N):" -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Nn]$ ]]
    then
        SUB_DIR=""
    else
        echo "Aborted..."
        exit 0
    fi
fi

SRC=${USER_SRC}${SUB_DIR}

if [ ! -d "${SRC}" ]; then
    echo "directory does not exist..."
    echo "[FAILED]"
    exit 0
fi

execRepair()
{
    EXACT_MATCH="0"
    if [ ! -z "$1" -a "$1" = "1" ]; then
        EXACT_MATCH="1"
    fi

    for i in $(find ${SRC} -name "*.php");
    do
        echo "change in $i"
        findAndReplace ${i} "${EXACT_MATCH}"
    done
}

fixPHP4Construct()
{
    if (($(${GIT} diff | grep "^-[^-]" | wc -l ) > 0 ))
    then
        echo "Modified files exist! Please do a commit or stash before running this script..."
        exit 1
    fi
    echo "IX PHP4 style constructor..."
    # FIX PHP4 style constructor
    ## class XYZ {
    ##   /**
    ##   * Constructor of XYZ.
    ##   */
    ##  function XYZ() {
    ##  }
    ## }
    $PERL -i -e 'undef $/;while($_=<>){s/^(class\s+(\w+)\b.*^\s+function\s+)\2\b/\1__construct/gms;print $_;}' $(find ${SRC} -name "*.php")

    # FIX parent calls
    ## MyClass::MyClass();
    ## parent::MyClass();
    ## $this->MyClass();
    $PERL -pi -e 's/((?:parent|\2)::|\$this->)('$(echo $(${GIT} diff | grep "^-[^-]" | sed -r "s/-\s*function\s*([a-zA-Z0-9_]*).*$/\1/") | sed 's/ /|/g')')\b/parent::__construct/g' $(find ${SRC} -name "*.php")
}

## fixPHP4Construct
## sleep 2;

execRepair

#if [ -f "$CONFIG" ];
#then
#    . "$CONFIG"
#
#    count=${#AS_FIND[@]}
#    index=0
#    while [ "$index" -lt "$count" ]; do
#        FIND=${AS_FIND[$index]}
#        REPLACE_WITH=${AS_REPLACE[$index]}
#        execRepair 1
#        let "index++"
#    done
#else
#    execRepair
#fi
echo "--[DONE]--"
exit 0
