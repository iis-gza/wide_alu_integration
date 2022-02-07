/*
 * Copyright (C) 2020 ETH Zurich and University of Bologna
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "pmsis.h"
#include "string.h"

int main()
{
  uint32_t a[8];
  uint32_t b[8];
  uint32_t result[16];

  memset(a, 0, sizeof (a));
  memset(b, 0, sizeof (b));
  memset(result, 0, sizeof (result));

  a[0] = 3;
  b[0] = 5;
  set_delay(50);

  if((wide_multiply(a, b, result) != 0) || (result[0] != 15))
  {
    printf("ERROR\n");
    return -1;
  }
  else
  {
    printf("SUCCESS\n");
    return 0;
  }
}
