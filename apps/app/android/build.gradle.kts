allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val sharedBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(sharedBuildDir)

subprojects {
    project.layout.buildDirectory.set(sharedBuildDir.dir(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
