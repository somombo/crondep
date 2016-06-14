#!/bin/bash

#test somo
cd $(dirname "$0")

source config.sh

function error_exit {
    echo "$1" >&2   ## Send message to stderr. Exclude >&2 if you don't want it that way.
    exit "${2:-1}"  ## Return a code specified by $2 or 1 by default.
}

#Conventions
the_post_receive_hook=$my_repo/hooks/post-receive
the_pre_receive_hook=$my_repo/hooks/pre-receive
the_puller=$my_repo/puller/pull
the_log=$my_repo/puller/pull.log

#my git command
my_git="$(which git) --work-tree=$my_worktree --git-dir=$my_repo" 

#Script
echo "...  backing up worktree $my_worktree"
if [[ ! -L $my_worktree ]]; then
  mv $my_worktree $my_worktree.backup
else
  error_exit " ... Working tree is a symlink!"
fi

echo "... doing git init at $my_repo"
  git init --bare $my_repo
  
echo "... doing git pull from $my_origin"
  $my_git pull $my_origin master 
  

cat << EOF > $the_post_receive_hook
#!/bin/sh
$my_git checkout -f
EOF

cat << EOF > $the_pre_receive_hook
#!/bin/sh
$my_gitclean -fd
$my_git reset --hard HEAD
EOF

mkdir -p $my_repo/puller
cat << EOF > $the_puller
#!/bin/sh
cd $my_repo 
$my_git pull $my_origin master 
EOF

echo "... setting permissions of $the_post_receive_hook, $the_pre_receive_hook, $the_puller"
chmod +x $the_post_receive_hook $the_pre_receive_hook $the_puller

echo "... setting cron job"
(crontab -l ; echo "* * * * * $the_puller >> $the_log 2>&1") | sort - | uniq - | crontab -
(crontab -l ; echo "0 * * * * rm $the_log 2>&1") | sort - | uniq - | crontab -

echo ""
echo "===== Installation Complete !! ====="
