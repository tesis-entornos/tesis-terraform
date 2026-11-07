# tesis-terraform

Infraestructura del prototipo de la tesis sobre entornos efímeros vs. fijos, gestionada con Terraform.

## Estructura por capas

| Capa | Descripción | Estado |
|---|---|---|
| `compartida/` | Recursos de la cuenta compartida (`582621604637`), región `us-east-2`. | Inicial, sin recursos |
| `base-modelo/` | Base de cada modelo (efímero / fijo). | Pendiente |
| `entorno/` | Entornos individuales sobre la base del modelo. | Pendiente |

Cada capa es un root module independiente con su propio state.

## Uso

- Versión de Terraform fijada en `.terraform-version` (tfenv).
- El `.terraform.lock.hcl` de cada capa se versiona.
- La configuración de cada capa va en `values*.tfvars`, versionados (sin secretos).
  Cualquier otro `.tfvars` queda fuera del repo.
- El provider solo acepta credenciales de la cuenta indicada en `account_id`.

```sh
cd compartida
terraform init -backend-config=backend.hcl
terraform plan -var-file=values.tfvars -out=plan.tfplan
terraform apply plan.tfplan
```
