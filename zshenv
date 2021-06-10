ZSHENV_LOCAL=${HOME}/.zshenv.local
if ! grep "ADDISIONAL_ALLOWED_REPOS" ${ZSHENV_LOCAL} >/dev/null 2>&1 ;then
  echo "export ADDISIONAL_ALLOWED_REPOS=''" >> ${ZSHENV_LOCAL}
fi
