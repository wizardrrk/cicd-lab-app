pipeline {
    agent none  // No global agent — each stage picks its own

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        APP_NAME = 'cicd-lab-app'
        PYTHON_ENV = 'test'
    }

    stages {
        stage('Checkout') {
            agent any  // Runs on Jenkins master
            steps {
                echo "=========================================="
                echo " Building: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                echo "=========================================="
                checkout scm
                stash includes: '**', name: 'source-code'
            }
        }

        stage('Install & Test') {
            agent {
                docker {
                    image 'python:3.11-slim'
                }
            }
            steps {
                unstash 'source-code'
                sh '''
                    pip install --quiet -r requirements.txt
                    pip list | grep -E "Flask|pytest|requests"
                '''
            }
        }

        stage('Quality Checks') {
            agent {
                docker {
                    image 'python:3.11-slim'
                }
            }
            parallel {
                stage('Unit Tests') {
                    steps {
                        unstash 'source-code'
                        sh 'pip install --quiet -r requirements.txt'
                        sh 'python -m pytest tests/ -v --tb=short --junitxml=test-results.xml'
                    }
                    post {
                        always {
                            junit 'test-results.xml'
                        }
                    }
                }
                stage('Syntax Check') {
                    steps {
                        unstash 'source-code'
                        sh 'pip install --quiet -r requirements.txt'
                        sh '''
                            python -m py_compile app.py
                            echo "Syntax check passed"
                        '''
                    }
                }
                stage('Dependency Audit') {
                    steps {
                        unstash 'source-code'
                        sh '''
                            pip install --quiet -r requirements.txt
                            pip install pip-audit --quiet
                            pip-audit --requirement requirements.txt --format text || true
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            agent any  // Runs on master where Docker CLI is available
            steps {
                unstash 'source-code'
                script {
                    def imageTag = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(8)}"
                    env.IMAGE_TAG = imageTag

                    sh """
                        docker build \
                            --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                            --build-arg VERSION=${imageTag} \
                            -t ${APP_NAME}:${imageTag} \
                            -t ${APP_NAME}:latest \
                            .
                    """
                    echo "Image built: ${APP_NAME}:${imageTag}"
                }
            }
        }

        stage('Security Scan') {
            agent any
            steps {
                sh '''
                    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin latest

                    trivy image \
                        --severity CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        --format table \
                        cicd-lab-app:latest || {
                            echo "CRITICAL vulnerabilities found!"
                            exit 1
                        }

                    echo "Security scan passed!"
                '''
            }
        }

        stage('Smoke Test') {
            agent any
            steps {
                sh '''
                    CONTAINER_ID=$(docker run -d -p 9090:8080 cicd-lab-app:latest)
                    sleep 5

                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/health)

                    docker stop $CONTAINER_ID
                    docker rm $CONTAINER_ID

                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "Smoke test FAILED - HTTP $HTTP_CODE"
                        exit 1
                    fi
                    echo "Smoke test PASSED - HTTP $HTTP_CODE"
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline completed - Status: ${currentBuild.currentResult}"
        }
        success {
            echo "Build PASSED! Image: cicd-lab-app:${env.IMAGE_TAG}"
        }
        failure {
            echo "Build FAILED! Check logs above."
        }
    }
}
