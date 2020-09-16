#!/bin/bash
# I would run ansible-playbook backup_all.yaml instead.
#
# Below attempts to capture the aliasing and variables
# around ansible-playbook to make it a portable process,
# across users, machines, etc.
#
INSTALL_DIR="${INSTALL_DIR:-${HOME}/git}"
export INVENTORY=${INSTALL_DIR:-${INSTALL_DIR}/ocp-installer/ini/ocp-eqx-lab.ini}
INVENTORY=/root/git/ocp-installer/ini/ocp-eqx-lab.ini
INSTALL_DIR=/home/u111433/go/src/github.com/afcollins/openshift/bkp-ocp
BACKUPDIR=backupOCP
mkdir -p $BACKUPDIR
ANSIBLE_PLAYBOOK='ansible-playbook --private-key=${INSTALL_DIR}/ocp-installer/ocpadmn-id_ecdsa.encrypted -i $INVENTORY'

echo "#----------------------------------------------------------------#" >> $BACKUPDIR/bkp_log
echo "#------- INICIO BACKUP OCP - `date +'%d-%m-%Y %H:%M'` -------------------#" >> $BACKUPDIR/bkp_log
echo "#----------------------------------------------------------------#" >> $BACKUPDIR/bkp_log

echo "[`date +'%d-%m-%Y %H:%M'`] - Playbook Backup Configs ControlPlane" >> $BACKUPDIR/bkp_log
$ANSIBLE_PLAYBOOK -i $INVENTORY $INSTALL_DIR/backup-controlplane.yaml &&
echo "[`date +'%d-%m-%Y %H:%M'`] - Playbook Backup Etcds" >> $BACKUPDIR/bkp_log
$ANSIBLE_PLAYBOOK -i $INVENTORY $INSTALL_DIR/backup-etcds.yaml &&
echo "[`date +'%d-%m-%Y %H:%M'`] - Playbook Backup Configs Nodes" >> $BACKUPDIR/bkp_log
$ANSIBLE_PLAYBOOK -i $INVENTORY $INSTALL_DIR/backup-nodes.yaml &&
echo "[`date +'%d-%m-%Y %H:%M'`] - Playbook Backup Objects de Todos os Projetos" >> $BACKUPDIR/bkp_log
$ANSIBLE_PLAYBOOK -i $INVENTORY $INSTALL_DIR/backup-objects.yaml &&

echo "#----------------------------------------------------------------#" >> $BACKUPDIR/bkp_log
echo "#------- FIM BACKUP OCP - `date +'%d-%m-%Y %H:%M'` ----------------------#" >> $BACKUPDIR/bkp_log
echo "#----------------------------------------------------------------#" >> $BACKUPDIR/bkp_log
