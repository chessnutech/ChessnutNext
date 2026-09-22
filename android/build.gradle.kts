allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.test" &&
                requested.name == "runner" &&
                requested.version == "1.2+"
            ) {
                useVersion("1.3.0")
            }
            if (requested.group == "androidx.test" &&
                requested.name == "rules" &&
                requested.version == "1.2+"
            ) {
                useVersion("1.2.0")
            }
            if (requested.group == "androidx.test.espresso" &&
                requested.name == "espresso-core" &&
                requested.version == "3.3+"
            ) {
                useVersion("3.3.0")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
