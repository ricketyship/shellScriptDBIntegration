COMMAND_TO_EXECUTE="sqlplus -s $DB_USER/$DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$ip_address)(Port=1521))(CONNECT_DATA=(SID=$sid)))"

setup_env()
{
    rm -rf /tmp/log.log > /dev/null 2>&1
    rm -rf /tmp/log2.log > /dev/null 2>&1
}

dt()
{
    valid=0
    table_name=""
    setup_env

    if [ $# -eq 0 ]
    then
        echo "Usage is dt <table name>"
        echo "Do you want to enter interactive mode?"       
        read choice
        if [ "$choice" == "Y" -o "$choice" == "y" ]
        then
            echo "Enter table name"
            read table_name
        else
            valid=0
        fi
    else
        table_name=$1
    fi

    if [ "x$table_name" != "x" ]
    then
        $COMMAND_TO_EXECUTE << EOF > /tmp/log.log
            set heading off;
            set feedback off ;
            set serveroutput off ;
            desc $table_name;
            exit ;
EOF
        grep ERROR /tmp/log.log
        if [ $? -eq 0 ]
        then
            >/tmp/log.log
            echo "Table Not Found. Following are the possible ones:"
            t $table_name ;
        else
            cat /tmp/log.log
            rm /tmp/log.log
        fi
    fi
}

t()
{
    valid=0
    table_name=""

    if [ $# -eq 0 ]
    then
        echo "Usage is t <tname to match>"
        echo "Do you want to enter interactive mode?"       
        read choice
        if [ "$choice" == "Y" -o "$choice" == "y" ]
        then
            echo "Enter table name"
            read table_name
        else
            valid=0
        fi
    else
        table_name=$1
    fi

    if [ "x$table_name" != "x" ]
    then
        $COMMAND_TO_EXECUTE << EOF 
            set heading off;
            set feedback off ;
            select tname from tab where tname like UPPER('%$table_name%');
            exit ;
EOF
    fi
}

get_table_fields()
{
$COMMAND_TO_EXECUTE << EOF > /tmp/log2.log
    set heading off;
    set feedback off ;
    set serveroutput off ;
    desc $1;
    exit ;
EOF

    str=""
    #string=`awk '$1 ~ /^[A-Z]+[_]?[A-Z]+$/ { if(str == "") {str=$1} else {str= str"||\"|\"||"$1}} END{print str}' /tmp/log2.log`
    string=`awk -F' ' '$1 ~ /^[A-Z].*/ { if (NR == 1) next ;if(str == "") {str=$1} else {str= str"||\"|\"||"$1}} END{print str}' /tmp/log2.log`
    #string=`awk -F' ' '$1 ~ /^[A-Z].*/ { if (NR == 1) next ;if(str == "") {str=$1} else {str= str"||\"chr(10)\"||"$1}} END{print str}' /tmp/log2.log`
    #string=`awk '$1 ~ /^[A-Z]+_.*[A-Z]+$/ { if(str == "") {str="substr(to_char("$1"),0, 15)"} else {str= str"||\"|\"||substr(to_char("$1"), 0, 15)"}} END{print str}' /tmp/log2.log`
    str=`echo $string | sed s/\"/\'/g`

    rm /tmp/log2.log > /dev/null

    if [ "x$str" == "x" ]
    then
        echo "Could not fetch database columns"
        exit 1
    else
        echo $str
    fi
}

q()
{
    invalid=0
    whereclausepresent=1
    interactive=0
    return_value=""
    setup_env

    if [ $# -eq 0 ]
    then
        echo "Usage is: q <table> [<column list> -<where clause>]"
        echo -e "\033[32mDo you want to enter interactive mode?(Yy/Nn)"
        echo -e "\033[0m"
        read choice
        if [ "$choice" == "Y" -o "$choice" == "y" ]
        then
            echo "Enter Table Name: "
            read table
            echo "Enter Columns (space separated): "
            read columns
            echo "Where Clause?:"
            read whereclause
            interactive=1
        else
            echo -e "\033[34mLeaving interactive mode!!! Ciao!!"
            echo -e "\033[0m"
            invalid=1
        fi
    fi

    # Test if the query has a where clause delimiter. if not, then execute the following
    if [ $interactive == 1 -a "x$whereclause" = "x" ]
    then
        whereclausepresent=0
    fi

    echo $* | grep - > /dev/null
    if [ $interactive == 0 -a $? -eq 1 ]
    then
        whereclausepresent=0
    fi

    if [ $# -eq 1 -o "x$columns" = "x" ]
    then
        columnsspecified=0
    fi

    if (( $interactive == 0 ))
    then
        table_name=$1
    else
        table_name=$table
    fi

    echo "$invalid" >> /tmp/log9.log
    echo "$whereclausepresent" >> /tmp/log9.log
    if [ "$invalid" == "0" ]
    then
        if (( $whereclausepresent == 0 ))
        then
            if (( $interactive == 1 ))
            then
                column_list_tmp=$columns
            else
                shift 1
                column_list_tmp=`echo $*`
            fi

            if [ "x$column_list_tmp" = "x" ]                        #Fetch all the fields in the table
            then
                column_list=$(get_table_fields $table_name)
            else                                                    #Fetch only the columns specified
                column_list=`echo $column_list_tmp  | sed -e "s# #||'|'||#g;"`
            fi

            statement="Select $column_list from $table_name;"

            if [ "x$return_value" == "x" ]
            then
                if [ "x$print_statement" == "x" ]
                then
                    echo "${bold}${underline}$statement${normal}"
                fi
                $COMMAND_TO_EXECUTE << EOF > /tmp/results.log
                    set heading off;
                        set feedback off ;
                    set pagesize 1000 ;
                    set lines 1000 ;
                    $statement
                    exit ;
EOF
            awk 'NF > 0 {print $0}' /tmp/results.log
            else
                echo -e "\033[35mFollowing issues where found with the query\n"
                echo -e "\033[35m$return_value"
                echo -e "\033[0m"
            fi
# If where clause present, then execute the following
        else
            if (( $interactive == 1 ))
            then
                where_clause=$whereclause
                column_list_tmp=$columns
            else
                where_clause_tmp=`echo $* | awk -F- 'END {print $2}'`
                where_clause=`echo $where_clause_tmp` #   | sed -e "s# # and #g; "`
                shift 1
                column_list_tmp=`echo $* | awk -F- 'END {print $1}'`
            fi

            if [ "x$column_list_tmp" = "x" ]                        #Fetch all the fields in the table
            then
                column_list=$(get_table_fields $table_name)
            else                                                    #Fetch only the columns specified
                column_list=`echo $column_list_tmp  | sed -e "s# #||'|'||#g;"`
            fi

            statement="Select $column_list from $table_name where $where_clause;"

            if [ "x$return_value" == "x" ]
            then
                if [ "x$print_statement" == "x" ]
                then
                    echo "${bold}${underline}$statement${normal}"
                fi
                $COMMAND_TO_EXECUTE << EOF > /tmp/results.log
                    set heading off;
                    set feedback off ;
                    $statement
                    exit ;
EOF
            awk 'NF > 0 {print $0}' /tmp/results.log
            else
                echo -e "\033[35mFollowing issues where found with the query\n"
                echo -e "\033[35m$return_value"
                echo -e "\033[0m"
            fi
       fi
    fi
    print_statement=""
}

