# tesis-terraform

Infraestructura del prototipo de la tesis sobre entornos efímeros vs. fijos, gestionada con Terraform.

## Estructura por capas

| Capa | Descripción | Estado |
|---|---|---|
| `compartida/` | Recursos de la cuenta compartida (`582621604637`), región `us-east-2`: bucket de states y repositorios ECR. | Aplicada |
| `estado/` | Bucket de states de cada cuenta de modelo (`tesis-entornos-tfstate-<account_id>`). Un state por modelo, en su propio bucket. | Fijo aplicado; efímero pendiente |
| `base-modelo/` | Base de cada modelo (efímero / fijo). | Fijo aplicado (DNS, certificados, VPC, ALB, RDS, ElastiCache y ECS); efímero pendiente |
| `entorno/` | Entornos individuales sobre la base del modelo, un state por entorno (`entornos/<slug>/terraform.tfstate`). | Backend escrito para el fijo (`compartido`); frontend pendiente |

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

## Bootstrap de `estado/` en una cuenta de modelo

La capa `estado/` crea el bucket donde se guarda su propio state, así que la primera vez
se aplica con state local y después se migra al bucket. Cada modelo tiene su
`values-<modelo>.tfvars` y su `backend-<modelo>.hcl` (fijo: `values-fijo.tfvars` y
`backend-fijo.hcl`; efímero: `values-efimero.tfvars` y `backend-efimero.hcl`).

Ejemplo para el efímero (para el fijo es igual, reemplazando `efimero` por `fijo`):

1. **Backend local temporal.** Crear `estado/backend_override.tf` (git lo ignora por la regla `*_override.tf`):

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

2. **Plan y apply con state local.** Revisar que el plan cree 3 recursos (bucket,
   versionado y bloqueo de acceso público) en la cuenta y la región correctas:

   ```sh
   cd estado
   terraform init
   terraform fmt -check
   terraform validate
   terraform plan -var-file=values-efimero.tfvars -out=estado-efimero.tfplan
   terraform apply estado-efimero.tfplan
   aws s3api get-bucket-versioning --bucket tesis-entornos-tfstate-<account_id> --profile tf-efimero
   ```

3. **Migración al bucket.** Borrar el override y migrar el state:

   ```sh
   rm backend_override.tf
   terraform init -migrate-state -backend-config=backend-efimero.hcl
   ```

4. **Verificación.** El plan tiene que dar `No changes` y el state tiene que estar en el bucket:

   ```sh
   terraform plan -var-file=values-efimero.tfvars
   aws s3 ls s3://tesis-entornos-tfstate-<account_id>/estado/ --profile tf-efimero
   ```

   Si el plan muestra cambios, no avanzar: el state local sigue siendo la copia de referencia.

5. **Limpieza.** Recién con el paso 4 verificado, borrar el state local y el plan:

   ```sh
   rm -f terraform.tfstate terraform.tfstate.backup estado-efimero.tfplan
   ```

Una vez hecho el bootstrap, el uso normal es:

```sh
cd estado
terraform init -reconfigure -backend-config=backend-efimero.hcl
terraform plan -var-file=values-efimero.tfvars -out=plan.tfplan
terraform apply plan.tfplan
```

`-reconfigure` hace falta al cambiar de modelo dentro del mismo directorio, porque
`.terraform/` recuerda el último backend inicializado.

## Entornos (`entorno/`)

Cada entorno es un state propio en el bucket del modelo, con key `entornos/<slug>/terraform.tfstate`.
`backend-<modelo>.hcl` no tiene key y `values-<modelo>.tfvars` solo tiene los valores del modelo:
lo propio de cada entorno se pasa por línea de comandos.

| Variable | Qué es | Ejemplo |
|---|---|---|
| `slug` | Identificador del entorno (`[a-z0-9-]`, hasta 20 caracteres). Va en los nombres de recursos, en el subdominio, en la base de datos (`app_<slug>` con `-` → `_`) y como prefijo de caché. | `compartido` |
| `n` | Número del entorno dentro del modelo (1 a 99). La regla del listener del ALB usa la prioridad `n * 10`, así que no se puede repetir dentro del modelo. | `1` |
| `backend_image` | Imagen del backend por digest (ver `imagenes-<fecha>/digests.md`). | `582621604637.dkr.ecr.us-east-2.amazonaws.com/tesis-backend@sha256:…` |

Ejemplo para el entorno `compartido` del fijo:

```sh
cd entorno
terraform init -reconfigure \
  -backend-config=backend-fijo.hcl \
  -backend-config="key=entornos/compartido/terraform.tfstate"
terraform plan -var-file=values-fijo.tfvars \
  -var slug=compartido -var n=1 \
  -var backend_image=582621604637.dkr.ecr.us-east-2.amazonaws.com/tesis-backend@sha256:<digest> \
  -out=entorno.tfplan
terraform apply entorno.tfplan
```

Para el efímero es lo mismo con `backend-efimero.hcl`, `values-efimero.tfvars` y su propio `slug` y `n`.
`-reconfigure` hace falta cada vez que se cambia de entorno en el mismo directorio.

La base de datos `app_<slug>` no la crea Terraform: la crea `scripts/reset_baseline.py` del
backend (`DROP DATABASE IF EXISTS` + `CREATE DATABASE`, migraciones y superusuario).
