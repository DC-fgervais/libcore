# -*- mode: makefile -*-
# Copyright (C) 2007 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Definitions for building the Java library and associated tests.
#

#
# Common definitions for host and target.
#

# libcore is divided into modules.
#
# The structure of each module is:
#
#   src/
#       main/               # To be shipped on every device.
#            java/          # Java source for library code.
#            native/        # C++ source for library code.
#            resources/     # Support files.
#       test/               # Built only on demand, for testing.
#            java/          # Java source for tests.
#            native/        # C++ source for tests (rare).
#            resources/     # Support files.
#
# All subdirectories are optional (hence the "2> /dev/null"s below).

include $(LOCAL_PATH)/openjdk_java_files.mk
include $(LOCAL_PATH)/non_openjdk_java_files.mk

define all-test-java-files-under
$(foreach dir,$(1),$(patsubst ./%,%,$(shell cd $(LOCAL_PATH) && (find $(dir)/src/test/java -name "*.java" 2> /dev/null) | grep -v -f java_tests_blacklist)))
endef

define all-core-resource-dirs
$(shell cd $(LOCAL_PATH) && ls -d */src/$(1)/{java,resources} 2> /dev/null)
endef

# The Java files and their associated resources.
core_resource_dirs := \
  luni/src/main/java \
  ojluni/src/main/resources/
test_resource_dirs := $(call all-core-resource-dirs,test)
test_src_files := $(call all-test-java-files-under,dalvik dalvik/test-rules dom harmony-tests json luni xml)
ojtest_src_files := $(call all-test-java-files-under,ojluni)

ifeq ($(EMMA_INSTRUMENT),true)
ifneq ($(EMMA_INSTRUMENT_STATIC),true)
    nojcore_src_files += $(call all-java-files-under, ../external/emma/core ../external/emma/pregenerated)
    core_resource_dirs += ../external/emma/core/res ../external/emma/pregenerated/res
endif
endif

local_javac_flags=-encoding UTF-8
#local_javac_flags+=-Xlint:all -Xlint:-serial,-deprecation,-unchecked
local_javac_flags+=-Xmaxwarns 9999999


#
# ICU4J related rules.
#
# We compile android_icu4j along with core-libart because we're implementing parts of core-libart
# in terms of android_icu4j.
android_icu4j_root := ../external/icu/android_icu4j/
android_icu4j_src_files := $(call all-java-files-under,$(android_icu4j_root)/src/main/java)
android_icu4j_resource_dirs := $(android_icu4j_root)/resources

#
# Build for the target (device).
#

include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(openjdk_java_files) $(non_openjdk_java_files) $(android_icu4j_src_files) $(openjdk_lambda_stub_files)
LOCAL_JAVA_RESOURCE_DIRS := $(core_resource_dirs) $(android_icu4j_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-all
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_REQUIRED_MODULES := tzdata
LOCAL_CORE_LIBRARY := true
LOCAL_UNINSTALLABLE_MODULE := true
include $(BUILD_JAVA_LIBRARY)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(openjdk_java_files)
LOCAL_JAVA_RESOURCE_DIRS := $(core_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-oj
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all
LOCAL_NOTICE_FILE := $(LOCAL_PATH)/ojluni/NOTICE
LOCAL_REQUIRED_MODULES := tzdata
LOCAL_CORE_LIBRARY := true
include $(BUILD_JAVA_LIBRARY)

# Definitions to make the core library.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(non_openjdk_java_files) $(android_icu4j_src_files)
LOCAL_JAVA_RESOURCE_DIRS := $(android_icu4j_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-libart
LOCAL_ADDITIONAL_DEPENDENCIES += $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all
ifeq ($(EMMA_INSTRUMENT),true)
ifneq ($(EMMA_INSTRUMENT_STATIC),true)
    # For instrumented build, include Jacoco classes into core-libart.
    LOCAL_STATIC_JAVA_LIBRARIES := jacocoagent
endif # EMMA_INSTRUMENT_STATIC
endif # EMMA_INSTRUMENT
LOCAL_CORE_LIBRARY := true
LOCAL_REQUIRED_MODULES := tzdata
include $(BUILD_JAVA_LIBRARY)

# A library that exists to satisfy javac when
# compiling source code that contains lambdas.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(openjdk_lambda_stub_files) $(openjdk_lambda_duplicate_stub_files)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-lambda-stubs
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all
LOCAL_NOTICE_FILE := $(LOCAL_PATH)/ojluni/NOTICE
LOCAL_CORE_LIBRARY := true
LOCAL_UNINSTALLABLE_MODULE := true
include $(BUILD_JAVA_LIBRARY)

ifeq ($(LIBCORE_SKIP_TESTS),)
# A guaranteed unstripped version of core-oj and core-libart. This is required for ART testing in
# preopted configurations. See b/24535627.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(openjdk_java_files)
LOCAL_JAVA_RESOURCE_DIRS := $(core_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_DEX_PREOPT := false
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-oj-testdex
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all
LOCAL_NOTICE_FILE := $(LOCAL_PATH)/ojluni/NOTICE
LOCAL_REQUIRED_MODULES := tzdata
LOCAL_CORE_LIBRARY := true
include $(BUILD_JAVA_LIBRARY)

# Build libcore test rules for target
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(call all-java-files-under, dalvik/test-rules/src/main test-rules/src/main)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_MODULE := core-test-rules
LOCAL_JAVA_LIBRARIES := core-all
LOCAL_STATIC_JAVA_LIBRARIES := junit
include $(BUILD_STATIC_JAVA_LIBRARY)

# Build libcore test rules for host
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(call all-java-files-under, dalvik/test-rules/src/main test-rules/src/main)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_MODULE := core-test-rules-hostdex
LOCAL_JAVA_LIBRARIES := core-oj-hostdex core-libart-hostdex
LOCAL_STATIC_JAVA_LIBRARIES := junit-hostdex
include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(non_openjdk_java_files) $(android_icu4j_src_files)
LOCAL_JAVA_RESOURCE_DIRS := $(android_icu4j_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_DEX_PREOPT := false
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-libart-testdex
LOCAL_ADDITIONAL_DEPENDENCIES += $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all
LOCAL_CORE_LIBRARY := true
LOCAL_REQUIRED_MODULES := tzdata
include $(BUILD_JAVA_LIBRARY)
endif

ifeq ($(LIBCORE_SKIP_TESTS),)
# Make the core-tests library.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(test_src_files)
LOCAL_JAVA_RESOURCE_DIRS := $(test_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVA_LIBRARIES := core-oj core-libart okhttp junit bouncycastle mockito-target
LOCAL_STATIC_JAVA_LIBRARIES := \
	core-test-rules \
	core-tests-support \
	mockwebserver \
	nist-pkix-tests \
	sqlite-jdbc
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_ERROR_PRONE_FLAGS := -Xep:TryFailThrowable:ERROR
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-tests
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
include $(BUILD_STATIC_JAVA_LIBRARY)
endif

ifeq ($(LIBCORE_SKIP_TESTS),)
# Make the core-tests-support library.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(call all-test-java-files-under,support)
LOCAL_JAVA_RESOURCE_DIRS := $(test_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVA_LIBRARIES := core-oj core-libart junit bouncycastle
LOCAL_STATIC_JAVA_LIBRARIES := bouncycastle-bcpkix bouncycastle-ocsp
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE := core-tests-support
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
include $(BUILD_STATIC_JAVA_LIBRARY)
endif

ifeq ($(LIBCORE_SKIP_TESTS),)
# Make the jsr166-tests library.
include $(CLEAR_VARS)
LOCAL_SRC_FILES :=  $(call all-test-java-files-under, jsr166-tests)
LOCAL_JAVA_RESOURCE_DIRS := $(test_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVA_LIBRARIES := core-oj core-libart junit
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE := jsr166-tests
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
include $(BUILD_STATIC_JAVA_LIBRARY)
endif

# Make the core-ojtests library.
ifeq ($(LIBCORE_SKIP_TESTS),)
    include $(CLEAR_VARS)
    LOCAL_NO_STANDARD_LIBRARIES := true
    LOCAL_JAVA_LIBRARIES := core-oj core-libart okhttp bouncycastle
    LOCAL_STATIC_JAVA_LIBRARIES := testng
    LOCAL_JAVACFLAGS := $(local_javac_flags)
    LOCAL_MODULE_TAGS := optional
    LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    LOCAL_MODULE := core-ojtests
    LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
    # jack bug workaround: int[] java.util.stream.StatefulTestOp.-getjava-util-stream-StreamShapeSwitchesValues() is a private synthetic method in an interface which causes a hard verifier error
    LOCAL_DEX_PREOPT := false # disable AOT preverification which breaks the build. it will still throw VerifyError at runtime.
    include $(BUILD_JAVA_LIBRARY)
endif

# Make the core-ojtests-public library. Excludes any private API tests.
ifeq ($(LIBCORE_SKIP_TESTS),)
    include $(CLEAR_VARS)
    # Filter out SerializedLambdaTest because it depends on stub classes and won't actually run.
    LOCAL_SRC_FILES := $(filter-out %/DeserializeMethodTest.java %/SerializedLambdaTest.java ojluni/src/test/java/util/stream/boot%,$(ojtest_src_files)) # Do not include anything from the boot* directories. Those directories need a custom bootclasspath to run.
    # Include source code as part of JAR
    LOCAL_JAVA_RESOURCE_DIRS := ojluni/src/test/dist
    LOCAL_NO_STANDARD_LIBRARIES := true
    LOCAL_JAVA_LIBRARIES := core-oj core-libart okhttp bouncycastle testng
    LOCAL_JAVACFLAGS := $(local_javac_flags)
    LOCAL_MODULE_TAGS := optional
    LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    LOCAL_MODULE := core-ojtests-public
    LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
    # jack bug workaround: int[] java.util.stream.StatefulTestOp.-getjava-util-stream-StreamShapeSwitchesValues() is a private synthetic method in an interface which causes a hard verifier error
    LOCAL_DEX_PREOPT := false # disable AOT preverification which breaks the build. it will still throw VerifyError at runtime.
    include $(BUILD_JAVA_LIBRARY)
endif

#
# Build for the host.
#

ifeq ($(HOST_OS),linux)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(call all-java-files-under, dex/src/main)
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := dex-host
include $(BUILD_HOST_JAVA_LIBRARY)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(non_openjdk_java_files) $(openjdk_java_files) $(android_icu4j_src_files) $(openjdk_lambda_stub_files)
LOCAL_JAVA_RESOURCE_DIRS := $(core_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-all-hostdex
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_REQUIRED_MODULES := tzdata-host
LOCAL_CORE_LIBRARY := true
LOCAL_UNINSTALLABLE_MODULE := true
include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(openjdk_java_files)
LOCAL_JAVA_RESOURCE_DIRS := $(core_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-oj-hostdex
LOCAL_NOTICE_FILE := $(LOCAL_PATH)/ojluni/NOTICE
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all-hostdex
LOCAL_REQUIRED_MODULES := tzdata-host
LOCAL_CORE_LIBRARY := true
include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)

# Definitions to make the core library.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(non_openjdk_java_files) $(android_icu4j_src_files)
LOCAL_JAVA_RESOURCE_DIRS := $(android_icu4j_resource_dirs)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-libart-hostdex
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-oj-hostdex
LOCAL_REQUIRED_MODULES := tzdata-host
include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)

# A library that exists to satisfy javac when
# compiling source code that contains lambdas.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(openjdk_lambda_stub_files) $(openjdk_lambda_duplicate_stub_files)
LOCAL_NO_STANDARD_LIBRARIES := true
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_TAGS := optional
LOCAL_JAVA_LANGUAGE_VERSION := 1.8
LOCAL_MODULE := core-lambda-stubs-hostdex
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
LOCAL_JAVA_LIBRARIES := core-all-hostdex
LOCAL_CORE_LIBRARY := true
include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)

# Make the core-tests-hostdex library.
ifeq ($(LIBCORE_SKIP_TESTS),)
    include $(CLEAR_VARS)
    LOCAL_SRC_FILES := $(test_src_files)
    LOCAL_JAVA_RESOURCE_DIRS := $(test_resource_dirs)
    LOCAL_NO_STANDARD_LIBRARIES := true
    LOCAL_JAVA_LIBRARIES := core-oj-hostdex core-libart-hostdex okhttp-hostdex bouncycastle-hostdex junit-hostdex core-tests-support-hostdex mockito-api-hostdex
    LOCAL_STATIC_JAVA_LIBRARIES := sqlite-jdbc-host mockwebserver-host nist-pkix-tests-host core-test-rules-hostdex
    LOCAL_JAVACFLAGS := $(local_javac_flags)
    LOCAL_MODULE_TAGS := optional
    LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    LOCAL_MODULE := core-tests-hostdex
    LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
    include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)
endif

# Make the core-tests-support library.
ifeq ($(LIBCORE_SKIP_TESTS),)
    include $(CLEAR_VARS)
    LOCAL_SRC_FILES := $(call all-test-java-files-under,support)
    LOCAL_JAVA_RESOURCE_DIRS := $(test_resource_dirs)
    LOCAL_NO_STANDARD_LIBRARIES := true
    LOCAL_JAVA_LIBRARIES := core-oj-hostdex core-libart-hostdex junit-hostdex bouncycastle-hostdex
    LOCAL_STATIC_JAVA_LIBRARIES := bouncycastle-bcpkix-hostdex bouncycastle-ocsp-hostdex
    LOCAL_JAVACFLAGS := $(local_javac_flags)
    LOCAL_MODULE_TAGS := optional
    LOCAL_MODULE := core-tests-support-hostdex
    LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
    include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)
endif

# Make the core-ojtests-hostdex library.
ifeq ($(LIBCORE_SKIP_TESTS),)
    include $(CLEAR_VARS)
    LOCAL_SRC_FILES := $(ojtest_src_files)
    LOCAL_NO_STANDARD_LIBRARIES := true
    LOCAL_JAVA_LIBRARIES := core-oj-hostdex core-libart-hostdex okhttp-hostdex bouncycastle-hostdex
    LOCAL_STATIC_JAVA_LIBRARIES := testng-hostdex
    LOCAL_JAVACFLAGS := $(local_javac_flags)
    LOCAL_MODULE_TAGS := optional
    LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    LOCAL_MODULE := core-ojtests-hostdex
    LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk
    include $(BUILD_HOST_DALVIK_JAVA_LIBRARY)
endif

endif # HOST_OS == linux

#
# Local droiddoc for faster libcore testing
#
#
# Run with:
#     mm -j32 libcore-docs
#
# Main output:
#     ../out/target/common/docs/libcore/reference/packages.html
#
# All text for proofreading (or running tools over):
#     ../out/target/common/docs/libcore-proofread.txt
#
# TODO list of missing javadoc, etc:
#     ../out/target/common/docs/libcore-docs-todo.html
#
# Rerun:
#     rm -rf ../out/target/common/docs/libcore-timestamp && mm -j32 libcore-docs
#
include $(CLEAR_VARS)

# for shared defintion of libcore_to_document
include $(LOCAL_PATH)/Docs.mk

# The libcore_to_document paths are relative to $(TOPDIR). We are in libcore so we must prepend
# ../ to make LOCAL_SRC_FILES relative to $(LOCAL_PATH).
LOCAL_SRC_FILES := $(addprefix ../, $(libcore_to_document))
# rerun doc generation without recompiling the java
LOCAL_JAVACFLAGS := $(local_javac_flags)
LOCAL_MODULE_CLASS:=JAVA_LIBRARIES

LOCAL_MODULE := libcore
LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/JavaLibrary.mk

LOCAL_DROIDDOC_OPTIONS := \
 -offlinemode \
 -title "libcore" \
 -proofread $(OUT_DOCS)/$(LOCAL_MODULE)-proofread.txt \
 -todo ../$(LOCAL_MODULE)-docs-todo.html \
 -knowntags ./libcore/known_oj_tags.txt \
 -hdf android.whichdoc offline

LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR:=build/tools/droiddoc/templates-sdk

include $(BUILD_DROIDDOC)

openjdk_java_files :=
non_openjdk_java_files :=
