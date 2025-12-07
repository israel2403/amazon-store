pipeline {
    agent any
    environment {
        DOCKERHUB_USERNAME = credentials('dockerhub-username-id')
        DOCKERHUB_TOKEN    = credentials('dockerhub-token-id')
        IMAGE_NAME         = "${DOCKERHUB_USERNAME}/amazon-api-users"
        IMAGE_TAG          = "${env.BUILD_NUMBER}"
        K8S_NAMESPACE      = "amazon-api"
    }
    triggers {
        pollSCM('H/1 * * * *')  // every 1 minute
    }
    stages {
        stage('Build & Test') {
            steps {
                dir('amazon-api-users') {
                    sh 'mvn clean package'
                }
            }
        }
        stage('Docker Build & Push') {
            when { 
                expression { env.GIT_BRANCH == 'origin/master' || env.GIT_BRANCH == 'master' }
            }
            steps {
                script {
                    dir('amazon-api-users') {
                        sh """
                            echo ${DOCKERHUB_TOKEN} | docker login -u ${DOCKERHUB_USERNAME} --password-stdin
                            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                            docker push ${IMAGE_NAME}:${IMAGE_TAG}
                            docker push ${IMAGE_NAME}:latest
                            docker logout
                        """
                    }
                }
            }
        }
        stage('Deploy to Minikube') {
            when { 
                expression { env.GIT_BRANCH == 'origin/master' || env.GIT_BRANCH == 'master' }
            }
            steps {
                sh 'bash k8s/deploy.sh'
            }
        }
    }
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
