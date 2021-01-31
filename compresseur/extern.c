/* RMNLIB - Library of useful routines for C and FORTRAN programming
 * Copyright (C) 1975-2001  Division de Recherche en Prevision Numerique
 *                          Environnement Canada
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation,
 * version 2.1 of the License.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <inttypes.h>
#include <zlib.h>

/*
  Apply external compression routines to the data.
*/

// Prepare buffer data (e.g. from fstd98) for access as bytes.
int words2bytes (unsigned char *out, int lngw) {
  uint32_t *in = (uint32_t*)out;
  int insize = lngw*4;
  for (int i = 0; i < insize; i+=4) {
    uint32_t tmp = in[i/4];
    out[i] = tmp>>24;
    out[i+1] = (tmp>>16)&(0xFF);
    out[i+2] = (tmp>>8)&(0xFF);
    out[i+3] = (tmp)&(0xFF);
  }
  return 0;
}

// Convert an array of byte data into "words" (e.g. to supply back to fstd98).
int bytes2words (unsigned char *in, int insize) {
  uint32_t *out = (uint32_t*) in;
  for (int i = 0; i < insize; i+=4) {
    out[i/4] = (in[i]<<24) | (in[i+1]<<16) | (in[i+2]<<8) | (in[i+3]);
  }
  return 0;
}

// Decode a byte stream.
int decode_next (unsigned char *in, int insize, unsigned char *out, int outsize) {
  // Check if data has been "shuffled" (i.e. group highest-order bytes
  // together, followed by second-highest, etc.).
  // This may be used to improve compression in a subsequent step.
  if (strncmp(in,"SHFL",4) == 0) {
    unsigned char stride = in[4];
    unsigned char *work = (unsigned char *)malloc(outsize);
    int ret = decode_next (in+5, insize-5, work, outsize);
    if (ret != 0) return ret;
    int n = outsize / stride;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < stride; j++) {
        out[i*stride+j] = work[j*n+i];
      }
    }
    free(work);
    return 0;
  }
  // zlib compression.  Not the best for numerical data, but universally
  // available.
  else if (strncmp(in,"ZLIB",4) == 0) {
    z_stream inf;
    int ret;
    inf.zalloc = Z_NULL;
    inf.zfree = Z_NULL;
    inf.opaque = Z_NULL;
    inf.avail_in = 0;
    inf.next_in = Z_NULL;
    ret = inflateInit(&inf);
    inf.avail_in = insize-4;
    inf.next_in = in+4;
    inf.avail_out = outsize;
    inf.next_out = out;
    ret = inflate(&inf, Z_FINISH);
    inflateEnd(&inf);
    return 0;
  }
  printf ("Error: Don't know how to handle '%c%c%c%c' data encoding.\n", in[0], in[1], in[2], in[3]);
  return -1;
}

/*
  The entry point for decoding data.
*/
int decode_extern (uint32_t *data) {
  // Extract size info.
  uint32_t *ptr = data;
  int in_lngw = ptr[0]; ptr++;
  int out_lngw = ptr[0]; ptr++;
  int insize = in_lngw*4, outsize = out_lngw*4;
  unsigned char *in = (unsigned char *)malloc(insize);
  memcpy (in, ptr, insize);
  words2bytes(in,in_lngw);
  unsigned char *out = (unsigned char *)data;
  int ier = decode_next (in, insize, out, outsize);
  if (ier != 0) return ier;
  bytes2words(out,outsize);
  free (in);
  return 0;
}


/*
  The entry point for encoding data with zlib.
*/
int encode_zlib (uint32_t *data, int in_lngw, int stride) {
  int complevel = 4;
  int insize = in_lngw*4;
  unsigned char *in = (unsigned char *)malloc(insize);
  memcpy (in, data, insize);
  words2bytes(in, in_lngw);
  int outsize = insize;
  unsigned char *out = (unsigned char *)data;
  unsigned char *ptr = out;
  unsigned char *work = NULL;
  // Leave room for encoding size information.
  ptr += 8;

  // Check if we should pre-shuffle the data.
  if (stride > 0) {
    work = (unsigned char *)calloc(outsize,1);
    int n = insize / stride;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < stride; j++) {
        work[j*n+i] = in[i*stride+j];
      }
    }
    strncpy (ptr, "SHFL", 4);
    ptr[4] = stride;
    ptr += 5;
  }
  else {
    work = in;
  }

  strncpy (ptr, "ZLIB", 4);
  ptr += 4;
  outsize = outsize - (ptr-out);

  z_stream def;
  int ret;
  def.zalloc = Z_NULL;
  def.zfree = Z_NULL;
  def.opaque = Z_NULL;
  ret = deflateInit(&def, complevel);
  def.avail_in = insize;
  def.next_in = work;
  def.avail_out = outsize;
  def.next_out = ptr;
  ret = deflate (&def, Z_FINISH);
  if (ret == Z_STREAM_END) {
    outsize = (ptr-out) + (outsize - def.avail_out);
    while (outsize%8 != 0) outsize++;
  }

  if (stride > 0) free(work);
  deflateEnd(&def);

  // Encode the size information.
  uint32_t *words = NULL;
  if (ret == Z_STREAM_END) {
    bytes2words(out, outsize);
    words = (uint32_t*) out;
    words[0] = outsize/4;
    words[1] = in_lngw;
  }
  else { // No compression possible.
    bytes2words(in, insize);
    memcpy (out, in, insize);
    free (in);
    return 1;
  }

  free (in);

  return 0;
}
