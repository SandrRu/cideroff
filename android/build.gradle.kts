allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val compileSdkProp = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    compileSdkProp.invoke(androidExt, 36)
                } catch (_: Exception) {
                    try {
                        val compileSdkField = androidExt.javaClass.getMethod("setCompileSdk", Int::class.java)
                        compileSdkField.invoke(androidExt, 36)
                    } catch (_: Exception) {}
                }
            }
        }
    }

    // Выравниваем Java 1.8 без использования options.release
    tasks.withType(JavaCompile::class.java).configureEach {
        sourceCompatibility = "1.8"
        targetCompatibility = "1.8"
    }

    // Выравниваем Kotlin JVM Target на 1.8
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}