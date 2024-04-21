#!/bin/bash
kubectl create namespace nginx
kubectl apply -f nginx.yaml -n nginx

sleep 15

kubectl get pods -n nginx
kubectl get deployments -n nginx
kubectl get services -n nginx

