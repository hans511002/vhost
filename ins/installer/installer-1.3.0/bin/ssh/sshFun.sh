#!/bin/bash

#auto_smart_ssh test test@hadoop06 ls /var
auto_smart_ssh () {
    expect -c "set timeout -1;
                spawn ssh -o StrictHostKeyChecking=no $2 ${@:3};
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                "
    return $?
}


auto_scp () {
    expect -c "set timeout -1;
                spawn scp -o StrictHostKeyChecking=no ${@:2};
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 1;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                "
    return $?
}




auto_ssh_copy_id () {
    expect -c "set timeout -1;
                spawn ssh-copy-id $2;
                expect {
                    *(yes/no)* {send -- yes\r;exp_continue;}
                    *assword:* {send -- $1\r;exp_continue;}
                    eof        {exit 0;}
                }";
}

auto_add_user () {
    expect -c "set timeout -1;
                spawn ssh -o StrictHostKeyChecking=no $2 useradd $3;
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                " ;

	if test "$?" = "1"   ; then
	 	usleep 1000;
		pass=$4
		if  test "$pass" = "" ; then
			pass=$3;
		fi
		auto_passwd_user $1 $2 $3 $pass
		return $?
    fi
    return $?
}
auto_passwd_user () {
  expect -c "set timeout -1;
               spawn ssh -o StrictHostKeyChecking=no $2  echo -e '${4}\n${4}'|passwd $3;
               expect {
                   *assword:* {send -- $1\r;
                                expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                   }
                   echo "ÃÜÂëÐÞ¸Ä³É¹¦"
                   eof         {exit 1;}
               }"
return $?
}

