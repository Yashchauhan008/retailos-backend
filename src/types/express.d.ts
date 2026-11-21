declare global {
  namespace Express {
    interface Request {
      validatedQuery?: any;
      id?: string;
      user?: {
        id: string;
        tenant_id?: string;
        tenant_user_id?: string;
        role_id?: string;
        branch_id?: string;
      };
      superAdmin?: {
        id: string;
      };
    }
  }
}

export {};
