# ai-store-api — 错误处理

## 全局异常过滤器

`common/filters/all-exceptions.filter.ts`：

```typescript
if (exception instanceof HttpException) {
  status = exception.getStatus();
  message = exception.message;
} else {
  status = 500;
  message = exception.message || '服务器内部错误';
}
response.status(status).json({ status, message, timestamp, path });
```

## Controller/Service 抛出异常

```typescript
throw new HttpException('门店编码不能为空', HttpStatus.BAD_REQUEST);
throw new HttpException('该用户无权限访问，请联系管理员', HttpStatus.FORBIDDEN);
throw new BadRequestException('ids 不能为空');  // NestJS 内置
```

## 两种响应格式（新旧混用）

```typescript
// 新模块：ResponseDto
return new ResponseDto(result);  // { status: 200, data: result }
return new ResponseDto(result, 'success'); // { status: 200, message: 'success', data: result }

// 旧模块：字面量
return { status: 200, data: { warnings, total } };
return { status: 200, message: '该预警项未上线...' };
```

## 写新代码时

**优先使用 `ResponseDto`**（`common/interfaces/response-data.interface.ts`），已有的旧模块字面量不动。
