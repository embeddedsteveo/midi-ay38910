# ATmega32 Controlled AY 3-8910 Midi Player
#
#
# Description
This project entails a standard midi decoder on the ATmega32 which controls three channels of a AY-3-8910, some features are
- Supports running note status
- Three channels
- Velocity control for volume

The project was written in assembly and compiled using AVR studio. The calculation for midi baud rate can be changed to suit your required clock. Internal clock has been tested and suffices for midi.

The lookup table for frequency generation was created using a 1MGhz reference clock, you cannot drive the AY-3-8910 faster than about 2MGhz, please check the data sheet for more information.
# Known problems

If the midi stream is interrupted, and no note off event is received, the last note playing on a channel will continue to play.

# Hardware
This project uses minimal parts, a 6N138 optocoupler was used to remove ground loops, you can refer to the midi specification for more information about [this](https://www.midi.org/specifications-old/item/midi-din-electrical-specification).

# Disclaimer
*THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE OR WARRANTIES OF NON-INFRINGEMENT, ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE/HARDWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.*

