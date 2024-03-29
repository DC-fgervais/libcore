/*
 * Copyright (C) 2016 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package dalvik.system;

/**
 * Holder class for extraneous Class data.
 *
 * This class holds data for Class objects that is either rarely useful, only necessary for
 * debugging purposes or both. This allows us to extend the Class class without impacting memory
 * use.
 *
 * @hide For internal runtime use only.
 */
public final class ClassExt {
    /**
     * An array of all obsolete DexCache objects that are needed for obsolete methods.
     *
     * These entries are associated with the obsolete ArtMethod pointers at the same indexes in the
     * obsoleteMethods array.
     *
     * This field has native components and is a logical part of the 'Class' type.
     */
    private Object[] obsoleteDexCaches;

    /**
     * An array of all native obsolete ArtMethod pointers.
     *
     * These are associated with their DexCaches at the same index in the obsoleteDexCaches array.
     *
     * This field is actually either an int[] or a long[] depending on size of a pointer.
     *
     * This field contains native pointers and is a logical part of the 'Class' type.
     */
    private Object obsoleteMethods;

    /**
     * If set, the original DexCache associated with the related class.
     *
     * In this instance 'original' means the dex-cache (and associated dex-file) for this class when
     * it was first loaded after all non-retransformation capable transformations had been performed
     * but before any retransformation capable ones had been done.
     *
     * Needed in order to implement retransformation of classes.
     *
     * This field has native components and is a logical part of the 'Class' type.
     */
    private Object originalDexCache;

    /**
     * If class verify fails, we must return same error on subsequent tries. We may store either
     * the class of the error, or an actual instance of Throwable here.
     *
     * This field is a logical part of the 'Class' type.
     */
    private Object verifyError;

    /**
    * Private constructor.
    *
    * Only created by the runtime.
    */
    private ClassExt() {}
}
