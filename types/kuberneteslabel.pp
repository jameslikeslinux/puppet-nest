# Thanks ChatGPT!
# @see https://kubernetes.io/docs/reference/kubectl/generated/kubectl_taint/
type Nest::KubernetesLabel = Pattern[/^((?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*\/)?[A-Za-z0-9][A-Za-z0-9._-]{0,252}))(?:=([A-Za-z0-9][A-Za-z0-9._-]{0,62}))?(?::(NoSchedule|PreferNoSchedule|NoExecute))?$/]
