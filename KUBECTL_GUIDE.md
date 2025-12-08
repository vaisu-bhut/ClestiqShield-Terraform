# Kubectl Command Guide
> **"The Remote Control for your Cluster"**

This guide covers the most essential commands you will use to manage your Clestiq Shield application on GKE.

## 1. The Basics (Moving things in and out)

### `kubectl apply`
**Command:** `kubectl apply -f <filename_or_directory>`
**Analogy:** "Make the house look like this blueprint."
**Usage:**
- `kubectl apply -f k8s/` : Deploys everything in the k8s folder.
- `kubectl apply -f k8s/gateway.yaml` : Updates just the gateway service.
**When to use:** Whenever you change your code or configuration and want to push the update.

### `kubectl delete`
**Command:** `kubectl delete -f <filename>` or `kubectl delete pod <pod_name>`
**Analogy:** "Throw this furniture out."
**Usage:**
- `kubectl delete -f k8s/gateway.yaml` : Completely removes the gateway from the cluster.
- `kubectl delete pod gateway-5f67b8-abcde` : Restarts a specific pod (Kubernetes will automatically create a new one to replace it!).

---

## 2. Inspection (Looking around)

### `kubectl get`
**Command:** `kubectl get <resource_type>`
**Analogy:** "Give me a list of checking inventory."
**Usage:**
- `kubectl get pods` : Lists running containers. Status should be `Running`.
- `kubectl get services` (or `svc`): Lists endpoints. Look here for your **External IP** to access the app.
- `kubectl get nodes` : Lists the servers (VMs) in your cluster.
- `kubectl get all` : Lists everything.

### `kubectl describe`
**Command:** `kubectl describe <resource_type> <name>`
**Analogy:** "Read the detailed tag on this item."
**Usage:**
- `kubectl describe pod gateway-5f67b8-abcde`
**When to use:** If a pod is stuck in `Pending` or `CrashLoopBackOff`, use this to see the **Events** section at the bottom. It will tell you *why* (e.g., "ImagePullBackOff" means it can't find your Docker image).

---

## 3. Debugging (Fixing issues)

### `kubectl logs`
**Command:** `kubectl logs <pod_name>`
**Analogy:** "Read the diary/journal."
**Usage:**
- `kubectl logs sentinel-7890-xyz` : Prints the output of your application code.
- `kubectl logs -f sentinel-7890-xyz` : **Follows** the logs in real-time (like tail -f).

### `kubectl exec`
**Command:** `kubectl exec -it <pod_name> -- /bin/bash`
**Analogy:** "Teleport inside the container."
**Usage:**
- Opens a terminal session *inside* the running container. Useful for checking if files exist or testing network connectivity from inside the pod.

---

## 4. Scaling (Growing/Shrinking)

### `kubectl scale`
**Command:** `kubectl scale deployment <name> --replicas=<number>`
**Analogy:** "I need 5 more chairs."
**Usage:**
- `kubectl scale deployment gateway --replicas=5` : Instantly increases the number of gateway pods to 5.
