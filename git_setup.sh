cd  $HOME/src/odoo;
git remote add odoo-dev git@github.com:odoo-dev/odoo.git;  # Add odoo-dev as a new remote.
git remote rename origin odoo;  # Change the name of origin (the odoo repository) to odoo.
git remote set-url --push odoo no_push;  # Remove the possibility to push directly to odoo (you can only push to odoo-dev).

cd  $HOME/src/enterprise;
git remote add enterprise-dev git@github.com:odoo-dev/enterprise.git;
git remote rename origin enterprise;
git remote set-url --push enterprise no_push;
