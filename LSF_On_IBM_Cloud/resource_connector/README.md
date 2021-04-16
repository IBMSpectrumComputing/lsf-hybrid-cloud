### Automation scripts to setup the LSF resource connector on an existing IBM Cloud VPC based LSF cluster

#### For a full step by step tutorial using this repository, see: 
https://cloud.ibm.com/docs/solution-tutorials?topic=solution-tutorials-hpc-lsf-vpc-auto-scale

#### To get the latest LSF Updates please see:
https://ibm.box.com/s/vqhaztioiz4zm7hsg8pm35qe1ts32xeq

#### To build a custom image for use by the LSF Resource connector, you will need to do the following: 

1. An LSF Custom image that you can use for the resource connector is available in a COS bucket at: 
https://s3.us-south.cloud-object-storage.appdomain.cloud/lsf-image-1q21-us-south/centos77-lsf-core.qcow2.  

2. Copy the image into a COS bucket on your IBM Cloud account using one of the methods described in the IBM Cloud documentation (e.g., rclone, Aspera, s3fs): at: https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage.  

3. Once the image is in your COS bucket, you can import it into the IBM Cloud VPC infrastructure using these instructions: https://cloud.ibm.com/docs/vpc?topic=vpc-managing-images.  

4. Once imported, You can get the image ID for this custom image from VPC view of the IBM Cloud console, or from the IBM cloud CLI with: "ibmcloud is images"

5. This image ID will be provided to the configuration scripts by specifying it to the GEN2_Image_ID: parameter of the GEN2-config.yml file as detailed in Step 8 of the tutorial 



