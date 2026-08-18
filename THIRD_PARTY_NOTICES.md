# Third-party notices

## SoundCloud Desktop Fork research reference

The public logged-out SoundCloud transport in this patch was implemented after reviewing:

- Teiwazik/SoundCloud-DesktopFork
- upstream zxcloli666/SoundCloud-Desktop

Those projects are distributed under the MIT License. Their approach of discovering the public SoundCloud web `client_id` from page hydration and refreshing it when invalid informed the compatibility fallback used here.

MIT License text for the reviewed fork:

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE.
