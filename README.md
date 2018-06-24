# k8s-hostmap

Quickly hacked together script which shows the allocation of CPU and memory in a Kubernetes cluster using a [treemap](https://developers.google.com/chart/interactive/docs/gallery/treemap)

Assumes you run a kube proxy from your local machine to the requested cluster with `kubectl proxy` on port 8001 (the default port)
