/**
 * Shared server-side client for Petfinder-Database-Distributor API
 * 
 * IMPORTANT: This client must ONLY be used in server-side code.
 * Never expose PETFINDER_DISTRIBUTOR_API_KEY in client bundles or browser code.
 */

const BASE_URL = 'https://petfinder-database-distributor.onrender.com';

/**
 * Get the API key from environment variables
 * Throws an error if the key is not set
 */
function getApiKey(): string {
  const apiKey = process.env.PETFINDER_DISTRIBUTOR_API_KEY;
  if (!apiKey) {
    throw new Error(
      'PETFINDER_DISTRIBUTOR_API_KEY environment variable is not set. ' +
      'This key must be stored server-side only and never exposed to clients.'
    );
  }
  return apiKey;
}

/**
 * Health check response
 */
export interface HealthCheckResponse {
  status: string;
  message: string;
}

/**
 * Pet record from CSV
 */
export interface PetRecord {
  link: string;
  pet_type: 'dog' | 'cat';
  name: string;
  location: string;
  age: string;
  gender: string;
  size: string;
  color: string;
  breed: string;
  spayed_neutered: 'True' | 'False';
  vaccinated: 'True' | 'False';
  special_needs: 'True' | 'False';
  kids_compatible: 'True' | 'False';
  dogs_compatible: 'True' | 'False';
  cats_compatible: 'True' | 'False';
  about_me: string;
  image: string;
}

/**
 * Parse CSV content into PetRecord array
 */
function parseCSV(csvContent: string): PetRecord[] {
  const lines = csvContent.trim().split('\n');
  if (lines.length < 2) {
    return [];
  }

  // Parse header
  const headers = lines[0].split(',').map(h => h.trim());
  const records: PetRecord[] = [];

  // Parse data rows
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue;

    // Simple CSV parsing (handles quoted fields)
    const values: string[] = [];
    let current = '';
    let inQuotes = false;

    for (let j = 0; j < line.length; j++) {
      const char = line[j];
      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === ',' && !inQuotes) {
        values.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    values.push(current.trim()); // Add last value

    if (values.length === headers.length) {
      const record: any = {};
      headers.forEach((header, index) => {
        record[header] = values[index] || '';
      });
      records.push(record as PetRecord);
    }
  }

  return records;
}

/**
 * Client error class
 */
export class PetfinderDistributorError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
    public response?: string
  ) {
    super(message);
    this.name = 'PetfinderDistributorError';
  }
}

/**
 * Shared client for Petfinder-Database-Distributor API
 */
export class PetfinderDistributorClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(baseUrl: string = BASE_URL) {
    this.baseUrl = baseUrl;
    this.apiKey = getApiKey();
  }

  /**
   * Perform authenticated request
   */
  private async makeRequest(
    path: string,
    options: RequestInit = {}
  ): Promise<Response> {
    const url = `${this.baseUrl}${path}`;
    
    const headers = new Headers(options.headers);
    headers.set('X-API-Key', this.apiKey);

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new PetfinderDistributorError(
        `API request failed: ${response.statusText}`,
        response.status,
        errorText
      );
    }

    return response;
  }

  /**
   * Health check endpoint
   * GET /
   */
  async healthCheck(): Promise<HealthCheckResponse> {
    const response = await this.makeRequest('/');
    return response.json();
  }

  /**
   * Get all pets as CSV
   * GET /pets.csv
   * 
   * Returns parsed PetRecord array
   */
  async getAllPets(): Promise<PetRecord[]> {
    const response = await this.makeRequest('/pets.csv');
    const csvContent = await response.text();
    return parseCSV(csvContent);
  }

  /**
   * Get all pets as raw CSV string
   * GET /pets.csv
   */
  async getAllPetsCSV(): Promise<string> {
    const response = await this.makeRequest('/pets.csv');
    return response.text();
  }

  /**
   * Get CSV response stream for streaming downloads
   * GET /pets.csv
   * 
   * Returns the Response object for streaming
   */
  async getCSVStream(): Promise<Response> {
    return this.makeRequest('/pets.csv');
  }

  /**
   * Process pets in chunks to avoid memory issues
   * Processes CSV line by line instead of loading all into memory
   */
  async *processPetsInChunks(chunkSize: number = 1000): AsyncGenerator<PetRecord[], void, unknown> {
    const response = await this.getCSVStream();
    const reader = response.body?.getReader();
    const decoder = new TextDecoder();
    
    if (!reader) {
      throw new Error('Response body is not readable');
    }

    let buffer = '';
    let headers: string[] = [];
    let chunk: PetRecord[] = [];
    let isFirstLine = true;

    try {
      while (true) {
        const { done, value } = await reader.read();
        
        if (done) {
          // Process remaining buffer
          if (buffer.trim()) {
            const records = this.parseCSVChunk(buffer, headers, isFirstLine);
            chunk.push(...records);
            if (chunk.length > 0) {
              yield chunk;
            }
          }
          break;
        }

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        
        // Keep last incomplete line in buffer
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (!line.trim()) continue;

          if (isFirstLine) {
            headers = line.split(',').map(h => h.trim());
            isFirstLine = false;
            continue;
          }

          const record = this.parseCSVLine(line, headers);
          if (record) {
            chunk.push(record);
            
            if (chunk.length >= chunkSize) {
              yield chunk;
              chunk = [];
            }
          }
        }
      }

      // Yield remaining chunk
      if (chunk.length > 0) {
        yield chunk;
      }
    } finally {
      reader.releaseLock();
    }
  }

  /**
   * Parse a single CSV line into a PetRecord
   */
  private parseCSVLine(line: string, headers: string[]): PetRecord | null {
    const values: string[] = [];
    let current = '';
    let inQuotes = false;

    for (let j = 0; j < line.length; j++) {
      const char = line[j];
      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === ',' && !inQuotes) {
        values.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    values.push(current.trim()); // Add last value

    if (values.length === headers.length) {
      const record: any = {};
      headers.forEach((header, index) => {
        record[header] = values[index] || '';
      });
      return record as PetRecord;
    }

    return null;
  }

  /**
   * Parse CSV chunk (for remaining buffer)
   */
  private parseCSVChunk(csvContent: string, headers: string[], isFirstLine: boolean): PetRecord[] {
    const lines = csvContent.trim().split('\n');
    const records: PetRecord[] = [];

    let startIndex = 0;
    if (isFirstLine && lines.length > 0) {
      headers = lines[0].split(',').map(h => h.trim());
      startIndex = 1;
    }

    for (let i = startIndex; i < lines.length; i++) {
      const line = lines[i];
      if (!line.trim()) continue;
      
      const record = this.parseCSVLine(line, headers);
      if (record) {
        records.push(record);
      }
    }

    return records;
  }

  /**
   * Trigger next batch/cycle refresh
   * 
   * Note: Based on the current API documentation, there isn't a specific
   * endpoint to trigger the next batch. The scraper works automatically.
   * This method calls the health check to verify the service is ready,
   * and can be extended when a trigger endpoint becomes available.
   */
  async triggerNextBatch(): Promise<void> {
    // Verify service is healthy
    await this.healthCheck();
    
    // If a specific trigger endpoint is added in the future,
    // it can be called here. For now, the scraper runs automatically.
    // Example: await this.makeRequest('/trigger-next-batch', { method: 'POST' });
  }
}

/**
 * Create a singleton instance of the client
 * Reuse this instance across all server components
 */
let clientInstance: PetfinderDistributorClient | null = null;

/**
 * Get or create the shared client instance
 */
export function getPetfinderDistributorClient(): PetfinderDistributorClient {
  if (!clientInstance) {
    clientInstance = new PetfinderDistributorClient();
  }
  return clientInstance;
}


