#!/bin/bash
# restore-db.sh

BACKUP_DIR=$1
POSTGRES_POD=$(kubectl get pod -n plateforme-electronique -l app=postgres -o jsonpath='{.items[0].metadata.name}')
POSTGRES_USER="postgres"

if [ -z "$BACKUP_DIR" ]; then
  echo "Usage: ./restore-db.sh ./backups/YYYYMMDD_HHMMSS"
  echo ""
  echo "Available backups:"
  ls -lt ./backups/
  exit 1
fi

echo "=== RESTORE FROM: $BACKUP_DIR ==="
echo "Pod: $POSTGRES_POD"
read -p "⚠️  Confirmer la restauration ? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Annulé."
  exit 0
fi

for DB in invoice_db payment_db subscription_db notification_db user_auth_db; do
  if [ -f "$BACKUP_DIR/$DB.sql" ]; then
    echo "Restoring $DB..."
    # Drop et recréer la base
    kubectl exec -n plateforme-electronique $POSTGRES_POD -- \
      psql -U $POSTGRES_USER -c "DROP DATABASE IF EXISTS $DB;"
    kubectl exec -n plateforme-electronique $POSTGRES_POD -- \
      psql -U $POSTGRES_USER -c "CREATE DATABASE $DB;"
    # Restaurer
    cat $BACKUP_DIR/$DB.sql | kubectl exec -i -n plateforme-electronique $POSTGRES_POD -- \
      psql -U $POSTGRES_USER $DB
    echo "  ✅ $DB restauré"
  else
    echo "  ⚠️  $DB.sql non trouvé, ignoré"
  fi
done

echo ""
echo "=== RESTORE COMPLETE ==="
