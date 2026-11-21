export type TaxBreakdown = {
  taxable: number;
  cgst: number;
  sgst: string | number;
  igst: number;
  taxTotal: number;
  lineTotal: number;
};

function round2(n: number) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function calculateLineTax(input: {
  quantity: number;
  unitPrice: number;
  discountAmount?: number;
  cgstRate: number;
  sgstRate: number;
  igstRate: number;
  interState?: boolean;
  taxInclusive?: boolean;
}): TaxBreakdown {
  const gross = input.quantity * input.unitPrice;
  const afterDiscount = Math.max(0, gross - (input.discountAmount || 0));

  if (input.taxInclusive) {
    const rate = input.interState
      ? input.igstRate
      : input.cgstRate + input.sgstRate;
    const taxable = rate > 0 ? afterDiscount / (1 + rate / 100) : afterDiscount;
    if (input.interState) {
      const igst = round2(afterDiscount - taxable);
      return {
        taxable: round2(taxable),
        cgst: 0,
        sgst: 0,
        igst,
        taxTotal: igst,
        lineTotal: round2(afterDiscount),
      };
    }
    const taxTotal = round2(afterDiscount - taxable);
    const cgst = round2(taxTotal / 2);
    const sgst = round2(taxTotal - cgst);
    return {
      taxable: round2(taxable),
      cgst,
      sgst,
      igst: 0,
      taxTotal,
      lineTotal: round2(afterDiscount),
    };
  }

  const taxable = round2(afterDiscount);
  if (input.interState) {
    const igst = round2((taxable * input.igstRate) / 100);
    return {
      taxable,
      cgst: 0,
      sgst: 0,
      igst,
      taxTotal: igst,
      lineTotal: round2(taxable + igst),
    };
  }

  const cgst = round2((taxable * input.cgstRate) / 100);
  const sgst = round2((taxable * input.sgstRate) / 100);
  return {
    taxable,
    cgst,
    sgst,
    igst: 0,
    taxTotal: round2(cgst + sgst),
    lineTotal: round2(taxable + cgst + sgst),
  };
}
