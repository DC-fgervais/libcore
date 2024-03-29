/*
 * Copyright (C) 2007 The Android Open Source Project
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

package libcore.util;

import android.system.ErrnoException;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import libcore.io.BufferIterator;
import libcore.io.MemoryMappedFile;

/**
 * A class used to initialize the time zone database. This implementation uses the
 * Olson tzdata as the source of time zone information. However, to conserve
 * disk space (inodes) and reduce I/O, all the data is concatenated into a single file,
 * with an index to indicate the starting position of each time zone record.
 *
 * @hide - used to implement TimeZone
 */
public final class ZoneInfoDB {
  private static final TzData DATA = TzData.loadTzDataWithFallback(
          System.getenv("ANDROID_DATA") + "/misc/zoneinfo/current/tzdata",
          System.getenv("ANDROID_ROOT") + "/usr/share/zoneinfo/tzdata");

  public static class TzData {
    /**
     * Rather than open, read, and close the big data file each time we look up a time zone,
     * we map the big data file during startup, and then just use the MemoryMappedFile.
     *
     * At the moment, this "big" data file is about 500 KiB. At some point, that will be small
     * enough that we could just keep the byte[] in memory, but using mmap(2) like this has the
     * nice property that even if someone replaces the file under us (because multiple gservices
     * updates have gone out, say), we still get a consistent (if outdated) view of the world.
     */
    private MemoryMappedFile mappedFile;

    private String version;
    private String zoneTab;

    /**
     * The 'ids' array contains time zone ids sorted alphabetically, for binary searching.
     * The other two arrays are in the same order. 'byteOffsets' gives the byte offset
     * of each time zone, and 'rawUtcOffsetsCache' gives the time zone's raw UTC offset.
     */
    private String[] ids;
    private int[] byteOffsets;
    private int[] rawUtcOffsetsCache; // Access this via getRawUtcOffsets instead.

    /**
     * ZoneInfo objects are worth caching because they are expensive to create.
     * See http://b/8270865 for context.
     */
    private final static int CACHE_SIZE = 1;
    private final BasicLruCache<String, ZoneInfo> cache =
        new BasicLruCache<String, ZoneInfo>(CACHE_SIZE) {
      @Override
      protected ZoneInfo create(String id) {
        BufferIterator it = getBufferIterator(id);
        if (it == null) {
          return null;
        }

        return ZoneInfo.makeTimeZone(id, it);
      }
    };

    /**
     * Loads the data at the specified paths in order, returning the first valid one as a
     * {@link TzData} object. If there is no valid one found a basic fallback instance is created
     * containing just GMT.
     */
    public static TzData loadTzDataWithFallback(String... paths) {
      for (String path : paths) {
        TzData tzData = new TzData();
        if (tzData.loadData(path)) {
          return tzData;
        }
      }

      // We didn't find any usable tzdata on disk, so let's just hard-code knowledge of "GMT".
      // This is actually implemented in TimeZone itself, so if this is the only time zone
      // we report, we won't be asked any more questions.
      System.logE("Couldn't find any tzdata!");
      return TzData.createFallback();
    }

    /**
     * Loads the data at the specified path and returns the {@link TzData} object if it is valid,
     * otherwise {@code null}.
     */
    public static TzData loadTzData(String path) {
      TzData tzData = new TzData();
      if (tzData.loadData(path)) {
        return tzData;
      }
      return null;
    }

    private static TzData createFallback() {
      TzData tzData = new TzData();
      tzData.populateFallback();
      return tzData;
    }

    private TzData() {
    }

    /**
     * Visible for testing.
     */
    public BufferIterator getBufferIterator(String id) {
      // Work out where in the big data file this time zone is.
      int index = Arrays.binarySearch(ids, id);
      if (index < 0) {
        return null;
      }

      BufferIterator it = mappedFile.bigEndianIterator();
      it.skip(byteOffsets[index]);
      return it;
    }

    private void populateFallback() {
      version = "missing";
      zoneTab = "# Emergency fallback data.\n";
      ids = new String[] { "GMT" };
      byteOffsets = rawUtcOffsetsCache = new int[1];
    }

    private boolean loadData(String path) {
      try {
        mappedFile = MemoryMappedFile.mmapRO(path);
      } catch (ErrnoException errnoException) {
        return false;
      }
      try {
        readHeader();
        return true;
      } catch (Exception ex) {
        try {
          mappedFile.close();
        } catch (ErrnoException ignored) {
        }

        // Something's wrong with the file.
        // Log the problem and return false so we try the next choice.
        System.logE("tzdata file \"" + path + "\" was present but invalid!", ex);
        return false;
      }
    }

    private void readHeader() {
      // byte[12] tzdata_version  -- "tzdata2012f\0"
      // int index_offset
      // int data_offset
      // int zonetab_offset
      BufferIterator it = mappedFile.bigEndianIterator();

      byte[] tzdata_version = new byte[12];
      it.readByteArray(tzdata_version, 0, tzdata_version.length);
      String magic = new String(tzdata_version, 0, 6, StandardCharsets.US_ASCII);
      if (!magic.equals("tzdata") || tzdata_version[11] != 0) {
        throw new RuntimeException("bad tzdata magic: " + Arrays.toString(tzdata_version));
      }
      version = new String(tzdata_version, 6, 5, StandardCharsets.US_ASCII);

      int index_offset = it.readInt();
      int data_offset = it.readInt();
      int zonetab_offset = it.readInt();

      readIndex(it, index_offset, data_offset);
      readZoneTab(it, zonetab_offset, (int) mappedFile.size() - zonetab_offset);
    }

    private void readZoneTab(BufferIterator it, int zoneTabOffset, int zoneTabSize) {
      byte[] bytes = new byte[zoneTabSize];
      it.seek(zoneTabOffset);
      it.readByteArray(bytes, 0, bytes.length);
      zoneTab = new String(bytes, 0, bytes.length, StandardCharsets.US_ASCII);
    }

    private void readIndex(BufferIterator it, int indexOffset, int dataOffset) {
      it.seek(indexOffset);

      // The database reserves 40 bytes for each id.
      final int SIZEOF_TZNAME = 40;
      // The database uses 32-bit (4 byte) integers.
      final int SIZEOF_TZINT = 4;

      byte[] idBytes = new byte[SIZEOF_TZNAME];
      int indexSize = (dataOffset - indexOffset);
      int entryCount = indexSize / (SIZEOF_TZNAME + 3*SIZEOF_TZINT);

      char[] idChars = new char[entryCount * SIZEOF_TZNAME];
      int[] idEnd = new int[entryCount];
      int idOffset = 0;

      byteOffsets = new int[entryCount];

      for (int i = 0; i < entryCount; i++) {
        it.readByteArray(idBytes, 0, idBytes.length);

        byteOffsets[i] = it.readInt();
        byteOffsets[i] += dataOffset; // TODO: change the file format so this is included.

        int length = it.readInt();
        if (length < 44) {
          throw new AssertionError("length in index file < sizeof(tzhead)");
        }
        it.skip(4); // Skip the unused 4 bytes that used to be the raw offset.

        // Don't include null chars in the String
        int len = idBytes.length;
        for (int j = 0; j < len; j++) {
          if (idBytes[j] == 0) {
            break;
          }
          idChars[idOffset++] = (char) (idBytes[j] & 0xFF);
        }

        idEnd[i] = idOffset;
      }

      // We create one string containing all the ids, and then break that into substrings.
      // This way, all ids share a single char[] on the heap.
      String allIds = new String(idChars, 0, idOffset);
      ids = new String[entryCount];
      for (int i = 0; i < entryCount; i++) {
        ids[i] = allIds.substring(i == 0 ? 0 : idEnd[i - 1], idEnd[i]);
      }
    }

    public String[] getAvailableIDs() {
      return ids.clone();
    }

    public String[] getAvailableIDs(int rawUtcOffset) {
      List<String> matches = new ArrayList<String>();
      int[] rawUtcOffsets = getRawUtcOffsets();
      for (int i = 0; i < rawUtcOffsets.length; ++i) {
        if (rawUtcOffsets[i] == rawUtcOffset) {
          matches.add(ids[i]);
        }
      }
      return matches.toArray(new String[matches.size()]);
    }

    private synchronized int[] getRawUtcOffsets() {
      if (rawUtcOffsetsCache != null) {
        return rawUtcOffsetsCache;
      }
      rawUtcOffsetsCache = new int[ids.length];
      for (int i = 0; i < ids.length; ++i) {
        // This creates a TimeZone, which is quite expensive. Hence the cache.
        // Note that icu4c does the same (without the cache), so if you're
        // switching this code over to icu4j you should check its performance.
        // Telephony shouldn't care, but someone converting a bunch of calendar
        // events might.
        rawUtcOffsetsCache[i] = cache.get(ids[i]).getRawOffset();
      }
      return rawUtcOffsetsCache;
    }

    public String getVersion() {
      return version;
    }

    public String getZoneTab() {
      return zoneTab;
    }

    public ZoneInfo makeTimeZone(String id) throws IOException {
      ZoneInfo zoneInfo = cache.get(id);
      // The object from the cache is cloned because TimeZone / ZoneInfo are mutable.
      return zoneInfo == null ? null : (ZoneInfo) zoneInfo.clone();
    }

    public boolean hasTimeZone(String id) throws IOException {
      return cache.get(id) != null;
    }

    @Override protected void finalize() throws Throwable {
      if (mappedFile != null) {
        mappedFile.close();
      }
      super.finalize();
    }

    /**
     * Returns the String describing the IANA version of the rules contained in the specified TzData
     * file. This method just reads the header of the file, and so is less expensive than mapping
     * the whole file into memory (and provides no guarantees about validity).
     */
    public static String getRulesVersion(File tzDataFile) throws IOException {
      try (FileInputStream is = new FileInputStream(tzDataFile)) {

        final int bytesToRead = 12;
        byte[] tzdataVersion = new byte[bytesToRead];
        int bytesRead = is.read(tzdataVersion, 0, bytesToRead);
        if (bytesRead != bytesToRead) {
          throw new IOException("File too short: only able to read " + bytesRead + " bytes.");
        }

        String magic = new String(tzdataVersion, 0, 6, StandardCharsets.US_ASCII);
        if (!magic.equals("tzdata") || tzdataVersion[11] != 0) {
          throw new IOException("bad tzdata magic: " + Arrays.toString(tzdataVersion));
        }
        return new String(tzdataVersion, 6, 5, StandardCharsets.US_ASCII);
      }
    }
  }

  private ZoneInfoDB() {
  }

  public static TzData getInstance() {
    return DATA;
  }
}
