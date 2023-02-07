use bufio;
use bytes;
use endian;
use errors;
use io;

// WAV file magic number.
const MAGIC: [4]u8 = ['R', 'I', 'F', 'F'];

// WAV file type header.
const FT_HEADER: [4]u8 = ['W', 'A', 'V', 'E'];

// Format chunk marker.
const FORMAT_CHUNK_MARKER: [4]u8 = ['f', 'm', 't', ' '];

// Marks the beginning of the data section.
const DATA_CHUNK_MARKER: [4]u8 = ['d', 'a', 't', 'a'];

// A WAV header.
type header = struct {
	format_data_len: u32,
	format_type: u16,
	n_channels: u16,
	sample_rate: u32,
	average_bps: u32,
	block_align: u16,
	bits_per_sample: u16,
};

export type reader = struct {
	vtable: io::stream,
	src: io::handle,
	head: header,
	remain: size,
	seen: [64]u32,
};

const qoi_vtable = io::vtable {
	reader = &wav_read,
	...
};

// Creates a new WAV [[reader]]. Reads and verifies the QOI magic and header
// before returning. Raw sample data may be read from returned [[io::stream]]
// object as 16-bit signed samples.
export fn newreader(
	src: io::handle,
) ((header, reader) | io::error | errors::invalid) = {
	let magic: [4]u8 = [0...];
	io::readall(src, magic)?;
	if (!bytes::equal(MAGIC, magic)) {
		return errors::invalid;
	};
	let head: [10]u8 = [0...];
	io::readall(src, head)?;

	const header = header {
		width = endian::begetu32(head[0..4]),
		height = endian::begetu32(head[4..8]),
		channels = head[8]: channels,
		colorspace = head[9]: colorspace,
	};
	if (header.width == 0 || header.height == 0) {
		return errors::invalid;
	};
	if (header.channels < channels::RGB || header.channels > channels::RGBA) {
		return errors::invalid;
	};
	if (header.colorspace > colorspace::LINEAR) {
		return errors::invalid;
	};

	return (header, reader {
		vtable = &qoi_vtable,
		src = src,
		head = header,
		remain = header.width * header.height,
		seen = [0...],
		color = 0xFF000000,
		count = 0,
	});
};

fn wav_read(st: *io::stream, buf: []u8) (size | io::error | io::EOF) = {
	const orig = len(buf);
	assert(len(buf) % size(u32) == 0,
		"image::qoi: buffer size not divisible by four");
	let buf = (buf: *[*]u32)[..len(buf) / 4];

	let rd = st: *reader;
	if (rd.remain == 0) {
		let buf: [8]u8 = [0...];
		io::readall(rd.src, buf)?;
		if (!bytes::equal(buf, QOI_END)) {
			return errors::invalid;
		};
		return io::EOF;
	};

	let z = 0z;
	for (len(buf) != 0 && rd.remain != 0) {
		if (rd.count == 0) {
			readtag(rd)?;
		};
		assert(rd.count != 0);

		let n = rd.count;
		if (n > len(buf)) {
			n = len(buf);
		};
		for (let i = 0z; i < n; i += 1) {
			buf[i] = rd.color;
		};
		buf = buf[n..];
		rd.remain -= n;
		rd.count -= n;
		z += n * 4;
	};

	return z;
};
