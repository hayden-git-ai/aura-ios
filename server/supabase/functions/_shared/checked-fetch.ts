export type FetchLike = typeof fetch;

export interface FetchRequest {
  input: Parameters<FetchLike>[0];
  init?: Parameters<FetchLike>[1];
}

/// Performs one HTTP request and rejects non-success responses without copying
/// a response body (which may contain private backend details) into the error.
export async function checkedFetch(
  operation: string,
  input: Parameters<FetchLike>[0],
  init: Parameters<FetchLike>[1],
  fetcher: FetchLike = fetch,
): Promise<Response> {
  const response = await fetcher(input, init);
  if (!response.ok) {
    throw new Error(`${operation} failed (${response.status})`);
  }
  return response;
}

/// Reads every JSON-array page exactly once using increasing offsets. The
/// caller supplies request construction so credentials stay at the call site.
export async function checkedArrayPages<T>(
  operation: string,
  pageSize: number,
  requestAtOffset: (offset: number) => FetchRequest,
  fetcher: FetchLike = fetch,
): Promise<T[]> {
  const all: T[] = [];
  let offset = 0;
  while (true) {
    const request = requestAtOffset(offset);
    const response = await checkedFetch(operation, request.input, request.init, fetcher);
    const page: unknown = await response.json();
    if (!Array.isArray(page)) throw new Error(`${operation} returned invalid data`);
    all.push(...page as T[]);
    if (page.length < pageSize) return all;
    offset += page.length;
  }
}

/// Sends a bounded sequence in fixed-size requests. Each chunk is checked
/// before the next begins, so a later failure rejects the overall operation.
export async function checkedFetchChunks<T>(
  operation: string,
  values: T[],
  chunkSize: number,
  requestForChunk: (chunk: T[]) => FetchRequest,
  fetcher: FetchLike = fetch,
): Promise<void> {
  if (!Number.isInteger(chunkSize) || chunkSize <= 0) {
    throw new Error(`${operation} has invalid chunk size`);
  }
  for (let offset = 0; offset < values.length; offset += chunkSize) {
    const request = requestForChunk(values.slice(offset, offset + chunkSize));
    await checkedFetch(operation, request.input, request.init, fetcher);
  }
}
