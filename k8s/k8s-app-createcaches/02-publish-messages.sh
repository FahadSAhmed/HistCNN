#!/bin/bash

echo -e "\nThis script creates metadata for tfrecords and publishes shard number for the k8s app."

echo -e "\nThis script assumes the cluster $cluster_name in project $project_id is up and running."
echo -e "If it's not the case please first create a cluster using ../01-create-k8s-cluster.sh"
echo -e "\nThis script also assumes you have created the service key ../service-key.json"
echo -e "If this is not true please first run ../02-set-service-account-once-per-project.sh"

echo -e "\nLoading global variables from ../00-project-config.sh...\n"
source ../00-project-config.sh

echo -e "\nLoading app variables from 00-app-config.sh...\n"
source 00-app-config.sh

credentials_path=`eval echo "~"`'/.config/service-key.json'
export GOOGLE_APPLICATION_CREDENTIALS="$credentials_path"

echo -e "project_id: $project_id"
echo -e "zone_name: $zone_name"
echo -e "cluster_name: $cluster_name"
echo -e "bucket_name: $bucket_name"
echo -e "tiles_input_path: $tiles_input_path"
echo -e "topic_name: $topic_name"
echo -e "subscription_name: $subscription_name"

clear_subscription()
{
    read -p "Would you like to clear up the queue from the subscription $subscription_name? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      echo -e "\nDeleting the old subscription..."
      gcloud pubsub subscriptions delete $subscription_name

      sleep 10s

      echo -e "\nCreating a pull subscription..."
      gcloud pubsub subscriptions create $subscription_name --ack-deadline=600 --topic=$topic_name --topic-project=$project_id

      echo -e "\nChecking the queue is empty..."
      gcloud pubsub subscriptions pull $subscription_name
    fi
}

clear_subscription

echo '' > /tmp/svs_path_list.txt
for cancertype in "${cancertypes[@]}"
do
  echo -e "\nFetching list of svs files for $cancertype and saving it to: /tmp/svs_path_list.txt"
  gsutil -m ls gs://$bucket_name/$tiles_input_path/$cancertype/${cancertype}_512x512/ >> /tmp/svs_path_list.txt
done

# Publishing messages
echo -e "\nPublishing the messages:"
python publish.py

echo -e "\nA sample message pulled (without acknowledgment):"
gcloud pubsub subscriptions pull $subscription_name
