node("${env.NODE}") {
  currentBuild.result = "SUCCESS"
  packages = []
  package_commit_map = [:]

  // TODO: Skip if "master" branch is not updated
  try {
    stage('Clean up') {
      deleteDir()
    }

    // Checkout https://github.com/riboseinc/packaging
    // stage('Checkout') {
    //   checkout([
    //     $class: 'GitSCM',
    //     branches: [[name: '*/master']],
    //     doGenerateSubmoduleConfigurations: false,
    //     extensions: [],
    //     submoduleCfg: [],
    //     userRemoteConfigs: [[url: 'https://github.com/riboseinc/rpm-specs']]
    //   ])
    // }

    // Find out which package was updated = PKGNAME
    stage('Find updated packages') {

      // github.com/riboseinc/yum:commits/$PKGNAME contains
      // the commit used to build the package.
      // We want to create a map of { $pkgname -> commit_hash }

      package_commit_map = [:]

      dir("yum-repo") {
        checkout([
          $class: 'GitSCM',
          branches: [[name: '*/master']],
          doGenerateSubmoduleConfigurations: false,
          extensions: [
              [$class: 'SparseCheckoutPaths',  sparseCheckoutPaths:[[$class:'SparseCheckoutPath', path:'commits/']]],
              [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: true, timeout: 10],
                      ],
          submoduleCfg: [],
          userRemoteConfigs: [[url: 'https://github.com/riboseinc/yum']]
        ])
        def files = findFiles(glob: 'commits/*')
        package_commit_map[files[0].name] = readFile(files[0].path)
      }

      // Then:
      // Detect which $pkgname has changed between commit_hash..HEAD
      // Select those $pkgnames

      for (kv in mapToList(package_commit_map)) {
        commits = sh(
          script: "git log --oneline --pretty=oneline --name-status \"^${kv[1]}\".. -- ${kv[0]}/ | grep -E '^[ARM].*\b' | grep \\.spec | cut -f 2 -d\$'\t'",
          returnStdout: true
        )

        println "Commits are: $commits"
        if (commits != null) {
          println "Needs to update ${kv[0]} package!"
          packages << kv[0]
        }
      }

    }

    stage('Build and publish updated packages') {
      // TODO: Import packager key (file or env) before executing script
      container_key_path = '/tmp/yum-packager.key'
      writeFile file: container_key_path, text: env.PACKAGE_KEY
      println "Package key:  ${env.PACKAGE_KEY}..."

      checkout([
        $class: 'GitSCM',
        branches: [[name: '*/master']],
        doGenerateSubmoduleConfigurations: false,
        extensions: [],
        submoduleCfg: [],
        userRemoteConfigs: [[url: 'https://github.com/riboseinc/packaging']]
      ])

      packages.each {
        this_package = it
        // Run ./docker.sh ${PKGNAME}
        println "Building package:  ${this_package}..."

        docker.image('centos:7').withRun(
          "--rm" +
          "-v ${pwd}:/usr/local/packaging " +
          "-v ${container_key_path}:/tmp/packager.key:ro " +
          "--workdir /usr/local/packaging " +
          "-e PACKAGER_KEY_PATH=/tmp/packager.key " +
          "-e REPO_USERNAME=\"${env.REPO_USERNAME}\" " +
          "-e REPO_PASSWORD=\"${env.REPO_PASSWORD}\" "
          //"-v ${volume_name}:/usr/local/yum " +
        ) {
          sh ". /usr/local/packaging/scripts/_common.sh; the_works ${this_package}"
        }

        println "Done."
      }
    }
  } catch (err) {
    currentBuild.result = 'FAILURE'
    throw err
  }

}

// Required due to JENKINS-27421
@NonCPS
List<List<?>> mapToList(Map map) {
  return map.collect { it ->
    [it.key, it.value]
  }
}