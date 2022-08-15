# devops-stack-helloworld-templates

Helm templates used to deploy the start page for the [DevOps Stack](https://devops-stack.io).


## Objective

We use this repository as an example of how to deploy an application using our DevOps Stack. This also allows the user to test some core functionality of a newly deployed cluster:
- check that Argo CD, Grafana, Prometheus and Alertmanager and respective interfaces have started;
- collection and visibility of metrics in Prometheus;
- deployment of Let's Encrypt SSL certificates by cert-manager;
- visibility of application logs in Kubernetes (`kubectl logs <pod_name>`).

Besides these objectives, the user can use this app as an entry point to access the web interfaces of the other services deployed by the DevOps Stack (Argo CD, Grafana, Prometheus and Alertmanager), as you can see in the following screenshot.

![helloworld](docs/images/screenshot.png)


## Chart templates

This chart deploys multiple Kubernetes objects in order to achieve the objectives above:

|Template|Description|
|---|---|
|[helloworld_deploy.yaml](apps/helloworld/templates/helloworld_deploy.yaml)|The Kubernetes Deployment describing the pod that is to be deployed. It is composed of two containers. The first is a customized Nginx container serving a static web page on port 80 and also some metrics on port 8080 (only accessible to the pod itself). The second is a Prometheus exporter that translates the metrics on port 8080 to a format readable by Prometheus (the source code is available [here](https://github.com/nginxinc/nginx-prometheus-exporter) and [these](https://github.com/nginxinc/nginx-prometheus-exporter#stub-status-metrics) are the metrics you should see).|
|[helloworld_hyperlinks_configmap.yaml](apps/helloworld/templates/helloworld_hyperlinks_configmap.yaml)|The Kubernetes ConfigMap mounted as a volume by the first pod above and that contains the hyperlink configuration used by the static web site. It is deployed in this manner because we need to dynamically generate the hyperlinks to the applications, using the name and domain of the cluster.|  
|[helloworld_clusterip.yaml](apps/helloworld/templates/helloworld_clusterip.yaml)|The Kubernetes Service that makes the ports from the pods above available to the rest of the cluster. Port 8080 will be called by the ingress and port 9113 will be scraped by Prometheus.|
|[helloworld_ingress.yaml](apps/helloworld/templates/helloworld_ingress.yaml)|This YAML file contains multiple templates related to the configuration of the reverse proxy. It deploys an HTTPS ingress while creating a new SSL certificate, a Traefik Middleware to redirect HTTP traffic to HTTPS and an HTTP ingress that uses said middleware.|
|[helloworld_servicemonitor.yaml](apps/helloworld/templates/helloworld_servicemonitor.yaml)|The Kubernetes ServiceMonitor that tells kube-prometheus-stack in the DevOps Stack to scrape the metrics port.|

## Application deployment

To use this app, you will need to add the following block to you Terraform code of your deployment.

```terraform
module "helloworld" {
  source           = "git::https://github.com/camptocamp/devops-stack-module-applicationset.git/"
  name             = "apps"
  argocd_namespace = "argocd"
  namespace        = "helloworld"

  depends_on = [module.argocd]

  generators = [
    {
      git = {
        repoURL  = "https://github.com/camptocamp/devops-stack-helloworld-templates.git/"
        revision = "main"

        directories = [
          {
            path = "apps/*"
          }
        ]
      }
    }
  ]
  template = {
    metadata = {
      name = "{{path.basename}}"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/camptocamp/devops-stack-helloworld-templates.git/"
        targetRevision = "main"
        path           = "{{path}}"

        helm = {
          valueFiles = []
          # The following value defines this global variables that will be available to all apps in apps/*
          # This apps needs these to generate the ingresses containing the name and base domain of the cluster. 
          values     = <<-EOT
            cluster:
              name: "${module.eks.cluster_name}"
              domain: "${module.eks.base_domain}"
          EOT
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "{{path.basename}}"
      }
      
      syncPolicy = {
        automated = {
          selfHeal = true
          prune    = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}
```

This block of code in fact defines an Argo CD application set that takes as a generator a Git repository, in this case, [this repository](https://github.com/camptocamp/devops-stack-helloworld-templates.git/). As such, with some modifications, you can use it as an example to deploy your own applications.

What it does is defining an application set (saved in the namespace `argocd`) and then iterates over each folder in `apps/*`, creating a Kubernetes namespace and an Argo CD application for each one, using the name of each subfolder.

Each one of these application subfolders is expected to contain a structure similar to the following:

```
apps
└── application_name
    ├── Chart.yaml
    ├── secrets.yaml
    ├── templates
    │   ├── template1.yaml
    │   ├── template2.yaml
    │   ├── template3.yaml
    │   └── _helpers.tpl
    └── values.yaml
```

## Checking functionality of the DevOps Stack using this application

1. Check that `helloworld` has been deployed by visiting `helloworld.apps.<your_cluster_name>.<your_cluster_domain>`.
2. Verify on your browser (or even in your prefered Kubernetes utility, such as `kubectl` or `k9s`) that a SSL certificate has been created for the website.
3. Click on each application link and verify that they have been started.
4. Use your prefered Kubernetes utility to check if you can see the logs for the deployed pod (you can force the generation of new log entries by refreshing the `helloworld` web page).
5. Login to Prometheus and make sure you can see the metrics for Nginx (a simple query for `nginx` should show all the metrics available).
