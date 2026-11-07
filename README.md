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
- Perfil AWS de `compartida/`: `tf-compartida`.

```sh
cd compartida
terraform init
terraform validate
```
