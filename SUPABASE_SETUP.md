# Configuración de Supabase

## Tablas Necesarias

### 1. Tabla `persons`
```sql
CREATE TABLE persons (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. Tabla `face_images`
```sql
CREATE TABLE face_images (
  id BIGSERIAL PRIMARY KEY,
  person_id BIGINT NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  embedding FLOAT8[] NOT NULL,
  confidence FLOAT8 DEFAULT 0.95,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT fk_person FOREIGN KEY (person_id) REFERENCES persons(id)
);
```

### 3. Storage Bucket `face-images`
- Nombre: `face-images`
- Público: Sí
- Política de acceso: Permitir subida y lectura pública

## Políticas de Seguridad (RLS)

### Para `persons`
```sql
-- Permitir lectura
CREATE POLICY "Enable read access for all users" ON persons
FOR SELECT USING (true);

-- Permitir inserción
CREATE POLICY "Enable insert for all users" ON persons
FOR INSERT WITH CHECK (true);

-- Permitir actualización
CREATE POLICY "Enable update for all users" ON persons
FOR UPDATE USING (true);

-- Permitir eliminación
CREATE POLICY "Enable delete for all users" ON persons
FOR DELETE USING (true);
```

### Para `face_images`
```sql
-- Permitir lectura
CREATE POLICY "Enable read access for all users" ON face_images
FOR SELECT USING (true);

-- Permitir inserción
CREATE POLICY "Enable insert for all users" ON face_images
FOR INSERT WITH CHECK (true);

-- Permitir actualización
CREATE POLICY "Enable update for all users" ON face_images
FOR UPDATE USING (true);

-- Permitir eliminación
CREATE POLICY "Enable delete for all users" ON face_images
FOR DELETE USING (true);
```

## Credenciales

Las credenciales ya están configuradas en `lib/supabase_service.dart`:
- URL: https://uvdiwniodvndsxembmxz.supabase.co
- Anon Key: (ya está en el código)

## Verificación

Después de crear las tablas, verifica que:
1. Las tablas `persons` y `face_images` existen
2. El storage bucket `face-images` está creado y público
3. Las políticas RLS están activas
4. Puedes subir archivos al bucket manualmente desde el panel de Supabase
