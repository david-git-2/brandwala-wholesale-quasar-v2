/** Thrown when a multi-line profile deposit stops after posting some lines. */
export class ProfileDepositPartialError extends Error {
  readonly postedCount: number;

  readonly totalCount: number;

  constructor(message: string, postedCount: number, totalCount: number) {
    super(message);
    this.name = 'ProfileDepositPartialError';
    this.postedCount = postedCount;
    this.totalCount = totalCount;
  }
}