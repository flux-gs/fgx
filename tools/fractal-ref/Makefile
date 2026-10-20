# Host reference oracle for the FGX 3200-color fractal explorer.
CC     ?= cc
CFLAGS ?= -O2 -Wall

fractal_ref: fractal_ref.c
	$(CC) $(CFLAGS) -o $@ fractal_ref.c -lm

.PHONY: selftest goldens clean
selftest: fractal_ref
	./fractal_ref --selftest

# Full-set view golden: cr in [-2.5,1.0], ci in [-1.5,1.5], 320x200, 255 iters.
# Q9 fixed point (FBITS=9): raw=value*512
#   cr0  = -2.5   * 2^12 = -10240
#   ci0  = -1.5   * 2^12 = -6144
#   step =  3.5/320 * 2^12 = 45  (round(0.010937500 * 4096))
goldens: fractal_ref
	@printf 'GOLDEN_FULLSET = '
	@./fractal_ref --raw -1152 -600 6 320 200 255 | shasum -a 256 | cut -d' ' -f1
	@# Small oracle-test tile (48x30, maxit 64) over the period-2 bulb region.
	@# cr0=-2.0*4096=-8192  ci0=-0.6*4096=-2458  step=45. Fast to compute on device.
	@printf 'GOLDEN_TILE = '
	@./fractal_ref --sum -1024 -307 6 48 30 64

clean:
	rm -f fractal_ref
