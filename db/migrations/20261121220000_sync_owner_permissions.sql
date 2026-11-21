-- migrate:up

-- Grant any missing permissions to all tenant owner roles
INSERT INTO tenant_role_permissions (tenant_role_id, permission_id)
SELECT tr.id, p.id
FROM tenant_roles tr
CROSS JOIN permissions p
WHERE tr.code = 'owner'
  AND NOT EXISTS (
    SELECT 1 FROM tenant_role_permissions x
    WHERE x.tenant_role_id = tr.id AND x.permission_id = p.id
  );

-- Grant manager finance/returns/reports basics
INSERT INTO tenant_role_permissions (tenant_role_id, permission_id)
SELECT tr.id, p.id
FROM tenant_roles tr
JOIN permissions p ON p.key IN (
  'finance.read','returns.write','reports.finance','reports.read',
  'transfers.write','attendance.manage','loyalty.manage','promotions.manage','serials.manage'
)
WHERE tr.code = 'manager'
  AND NOT EXISTS (
    SELECT 1 FROM tenant_role_permissions x
    WHERE x.tenant_role_id = tr.id AND x.permission_id = p.id
  );

-- migrate:down

SELECT 1;
