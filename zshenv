ZSHENV_LOCAL=${HOME}/.zshenv.local
if ! grep "ADDISIONAL_ALLOWED_REPOS" ${ZSHENV_LOCAL} >/dev/null 2>&1 ;then
  echo "export ADDISIONAL_ALLOWED_REPOS=''" >> ${ZSHENV_LOCAL}
fi

if ! grep "GIT_AUTHOR_NAME" ${ZSHENV_LOCAL} >/dev/null 2>&1 ;then
  echo 'GIT_USER=' >> ${ZSHENV_LOCAL}
  echo 'GIT_EMAIL=' >> ${ZSHENV_LOCAL}
  echo 'export GIT_COMMITTER_NAME=${GIT_USER}' >> ${ZSHENV_LOCAL}
  echo 'export GIT_AUTHOR_NAME=${GIT_USER}' >> ${ZSHENV_LOCAL}
  echo 'export GIT_COMMITTER_EMAIL=${GIT_EMAIL}' >> ${ZSHENV_LOCAL}
  echo 'export GIT_AUTHOR_EMAIL=${GIT_EMAIL}' >> ${ZSHENV_LOCAL}
fi
