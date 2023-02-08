use bufio;
use bytes;
use endian;
use errors;
use io;

// WAV file magic number.
const MAGIC: [4]u8 = ['R', 'I', 'F', 'F'];

// RIFF type ID.
const RIFF_TYPE_ID: [4]u8 = ['W', 'A', 'V', 'E'];

// Marks the beginning of the format chunk.
const FORMAT_CHUNK_MARKER: [4]u8 = ['f', 'm', 't', ' '];

// Marks the beginning of the data chunk.
const DATA_CHUNK_MARKER: [4]u8 = ['d', 'a', 't', 'a'];

// Marks the beginning of the associated data list chunk.
const LIST_CHUNK_MARKER: [4]u8 = ['L', 'I', 'S', 'T'];

// A WAV header.
export type header = struct {
	file_len: u32,
	format_type: u16,
	n_channels: u16,
	sample_rate: u32,
	average_bps: u32,
	block_align: u16,
	bits_per_sample: u16,
	data_bytelen: u32,
};

export type reader = struct {
	vtable: io::stream,
	src: io::handle,
	header: header,
	remain: size,
};

const wav_vtable = io::vtable {
	reader = &wav_read,
	...
};

// Creates a new WAV [[reader]]. Reads and verifies the QOI magic and header
// before returning. Raw sample data may be read from returned [[io::stream]]
// object as 16-bit signed samples.
export fn newreader(
	src: io::handle,
) ((header, reader) | io::error | errors::invalid) = {
	let header = header { ... };

	let buffer: [4]u8 = [0...];

	io::readall(src, buffer)?;
	if (!bytes::equal(MAGIC, buffer)) {
		return errors::invalid;
	};

	io::readall(src, buffer)?;
	header.file_len = endian::legetu32(buffer[0..4]);

	io::readall(src, buffer)?;
	if (!bytes::equal(RIFF_TYPE_ID, buffer)) {
		return errors::invalid;
	};

	io::readall(src, buffer)?;
	if (!bytes::equal(FORMAT_CHUNK_MARKER, buffer)) {
		return errors::invalid;
	};

	io::readall(src, buffer)?;
	const format_data_bytelen = endian::legetu32(buffer[0..4]);
	let head_buffer: []u8 = alloc([0...], format_data_bytelen);
	io::readall(src, head_buffer)?;
	header.format_type = endian::legetu16(head_buffer[0..2]);
	header.n_channels = endian::legetu16(head_buffer[2..4]);
	header.sample_rate = endian::legetu32(head_buffer[4..8]);
	header.average_bps = endian::legetu32(head_buffer[8..12]);
	header.block_align = endian::legetu16(head_buffer[12..14]);
	header.bits_per_sample = endian::legetu16(head_buffer[14..16]);
	free(head_buffer);


	io::readall(src, buffer)?;
	if (bytes::equal(LIST_CHUNK_MARKER, buffer)) {
		// Ignore list chunk.
		// TODO: Is there a way to do this without allocating
		// memory? io::seek() doesn't work.
		io::readall(src, buffer)?;
		const list_data_bytelen = endian::legetu32(buffer[0..4]);
		let list_buffer: []u8 = alloc([0...], list_data_bytelen);
		io::readall(src, list_buffer)?;
		io::readall(src, buffer)?;
	};

	if (!bytes::equal(DATA_CHUNK_MARKER, buffer)) {
		return errors::invalid;
	};

	io::readall(src, buffer)?;
	header.data_bytelen = endian::legetu32(buffer[0..4]);

	return (header, reader {
		vtable = &wav_vtable,
		src = src,
		header = header,
		remain = header.data_bytelen,
	});
};

fn wav_read(st: *io::stream, buf: []u8) (size | io::error | io::EOF) = {
	let rd = st: *reader;
	if (rd.remain == 0) {
		return io::EOF;
	};

	assert(len(buf) % size(u16) == 0,
		"audio::wav: buffer size not divisible by 2");
	if (rd.header.bits_per_sample != 16) {
		abort("BPS other than 16 not currently implemented");
	};

	return io::readall(rd.src, buf) as size;
};
