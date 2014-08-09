#!/bin/sh
####
#
# SuSE daily security check v2.0 by Marc Heuse <marc@suse.de>
#
# most code was ripped from the OpenBSD /etc/security script ;-)
#
####
#
# TODO: maybe directory writable checks for jobs run in crontab
#
. ./basic.inc

source helper.inc
source user_group_password_helper.inc
source misc_helper.inc

set_tmpdir $0

trap 'rm -rf $TMPDIR; exit 1' 0 1 2 3 13 15
LOG="$TMPDIR/security.log"
ERR="$TMPDIR/security.err"
OUT="$TMPDIR/security.out"
TMP1="$TMPDIR/security.tmp1"
TMP2="$TMPDIR/security.tmp2"

# /etc/passwd check
check_passwd


# /etc/shadow check
check_shadow

# /etc/group checking
check_group

#
# checking root's login scrips for secure path and umask
#
> $OUT
> $TMP1
> $TMP2
rhome=/root
umaskset=no
list="/etc/csh.cshrc /etc/csh.login"
for i in $list ; do
        if [ -s "$i" ] ; then
                if egrep umask $i > /dev/null ; then
                        umaskset=yes
                fi
                egrep umask $i |
                awk '$2 % 100 < 20 \
                        { print "Root umask is group writeable" }
                     $2 % 10 < 2 \
                        { print "Root umask is other writeable" }' >> $OUT
                SAVE_PATH=$PATH
                unset PATH 2> /dev/null || PATH="" # redhat ... 
                /bin/csh -f -s << end-of-csh > /dev/null 2>&1
                        test -f "$i" && (	# still a race
                            source $i
                            /bin/ls -ldcbg \$path > $TMP1
			)
end-of-csh
                PATH=$SAVE_PATH
                awk '{
                        if ($9 ~ /^\.$/) {
                                print "The root path includes .";
                                next;
                        }
                     }
                     $1 ~ /^d....w/ \
        { print "Root path directory " $9 " is group writeable." } \
                     $1 ~ /^d.......w/ \
        { print "Root path directory " $9 " is other writeable." }' \
                < $TMP1 >> $TMP2
        fi
done
if [ $umaskset = "no" -o -s "$TMP2" ] ; then
	sort -u $TMP2 > $OUT
        printf "\nChecking root csh paths, umask values:\n$list\n"
        if [ -s "$OUT" ] ; then
                cat "$OUT"
        fi
        if [ $umaskset = "no" ] ; then
                printf "\nRoot csh startup files do not set the umask.\n"
        fi
fi
> $OUT
> $TMP1
> $TMP2
rhome=/root
umaskset=no
list="/etc/profile ${rhome}/.profile ${rhome}/.bashrc ${rhome}/.bash_login"
for i in $list; do
        if [ -s "$i" ] ; then
                if egrep umask $i > /dev/null ; then
                        umaskset=yes
                fi
                egrep umask $i |
                awk '$2 % 100 < 20 \
                        { print "Root umask is group writeable" } \
                     $2 % 10 < 2 \
                        { print "Root umask is other writeable" }' >> $OUT
                SAVE_PATH=$PATH
                unset PATH 2> /dev/null || PATH="" # redhat again ...
                /bin/sh << end-of-sh > /dev/null 2>&1
                        file "$i" | grep -qw text && . $i
                        list=\`echo \$PATH | /usr/bin/sed -e 's/:/ /g'\`
			/bin/ls -ldgbT \$list > $TMP1
end-of-sh
                PATH=$SAVE_PATH
                awk '{
                        if ($9 ~ /^\.$/) {
                                print "The root path includes .";
                                next;
                        }
                     }
                     $1 ~ /^d....w/ \
        { print "Root path directory " $9 " is group writeable." } \
                     $1 ~ /^d.......w/ \
        { print "Root path directory " $9 " is other writeable." }' \
                < $TMP1 >> $TMP2

        fi
done
if [ $umaskset = "no" -o -s "$TMP2" ] ; then
	sort -u $TMP2 > $OUT
        printf "\nChecking root sh paths, umask values:\n$list\n"
        if [ -s "$OUT" ] ; then
                cat "$OUT"
        fi
        if [ $umaskset = "no" ] ; then
                printf "\nRoot sh startup files do not set the umask.\n"
        fi
fi


# Misc. file checks
# root/uucp/bin/daemon etc. should be in /etc/ftpusers.
check_ftpusers


# executables should not be in the /etc/aliases file.
no_exec_in_etcaliases 

# Files that should not have + signs.
check_no_plus

# .rhosts check
check_rhosts

# Check home directories.  Directories should not be owned by someone else
# or writeable.
check_home_directories_owners

# Files that should not be owned by someone else or writeable.
check_special_files_owner

# Mailboxes should be owned by user and unreadable.
check_mailboxes_owned_by_user_and_unreadable

# File systems should not be globally exported.
check_for_globally_exported_fs

# check remote and local devices
check_promisc

# list loaded modules
list_loaded_kernel_modules

# nfs mounts with missing nosuid
nfs_mounted_with_missing_nosuid

# display programs with bound sockets
display_programs_with_bound_sockets


####
#
# Cleaning up
#
rm -rf "$TMPDIR"
exit 0
# END OF SCRIPT
