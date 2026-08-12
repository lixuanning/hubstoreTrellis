# ai-store-api — 数据库指南

## 技术栈

TypeORM 0.2.25 + MySQL。`autoLoadEntities: true`，无需手动注册每个 Entity。

## Entity 规范

```typescript
@Entity('warnings') // 表名 snake_case
export class Warning {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'store_code' }) storeCode: string; // DB snake_case → TS camelCase
  @CreateDateColumn({ name: 'create_time' }) createTime: Date;
  @UpdateDateColumn({ name: 'update_time' }) updateTime: Date;
  @OneToMany(() => WarningImage, wi => wi.warning) images: WarningImage[];
  @ApiProperty() // Swagger 文档
}
```

## 查询方式（三种，按复杂度递进）

```typescript
// 1. Repository API — 简单查询
this.repo.find({ where: { storeCode, sent: 1 } });
this.repo.findOne(id, { relations: ['images'] });

// 2. QueryBuilder — 复杂查询（主流）
getRepository(Warning).createQueryBuilder('warning')
  .leftJoinAndSelect('warning.appeals', 'appeals')
  .where('warning.status = :s', { s: Status.NEW })
  .orderBy('warning.warning_status', 'ASC')
  .offset((page - 1) * pageCount).limit(pageCount)
  .getManyAndCount();

// 3. 原生 SQL — 极复杂场景
this.repo.query(`SELECT ... FROM warnings LEFT JOIN ...`);
```
