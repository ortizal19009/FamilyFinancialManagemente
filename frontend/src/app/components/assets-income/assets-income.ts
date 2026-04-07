import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-assets-income',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './assets-income.html',
  styleUrl: './assets-income.scss'
})
export class AssetsIncomeComponent implements OnInit {
  private apiService = inject(ApiService);

  assets: any[] = [];
  incomeRecords: any[] = [];
  familyMembers: any[] = [];
  editingAssetId: number | null = null;
  editingIncomeId: number | null = null;

  newAsset = {
    name: '',
    value: 0,
    owner: '',
    description: '',
    purchase_date: new Date().toISOString().split('T')[0]
  };

  newIncome = {
    amount: 0,
    source: '',
    income_date: new Date().toISOString().split('T')[0],
    description: ''
  };

  loadingAsset = false;
  loadingIncome = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.apiService.getAssets().subscribe(data => this.assets = data);
    this.apiService.getIncome().subscribe(data => this.incomeRecords = data);
    this.apiService.getFamilyMembers().subscribe(data => this.familyMembers = data);
  }

  onSubmitAsset() {
    this.loadingAsset = true;
    const request = this.editingAssetId === null
      ? this.apiService.createAsset(this.newAsset)
      : this.apiService.updateAsset(this.editingAssetId, this.newAsset);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingAssetId === null
          ? 'Bien registrado correctamente'
          : 'Bien actualizado correctamente';
        this.resetAssetForm();
        this.loadData();
        this.loadingAsset = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingAssetId === null
          ? 'Error al registrar el bien'
          : 'Error al actualizar el bien';
        this.loadingAsset = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onSubmitIncome() {
    this.loadingIncome = true;
    const request = this.editingIncomeId === null
      ? this.apiService.createIncome(this.newIncome)
      : this.apiService.updateIncome(this.editingIncomeId, this.newIncome);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingIncomeId === null
          ? 'Ingreso registrado correctamente'
          : 'Ingreso actualizado correctamente';
        this.resetIncomeForm();
        this.loadData();
        this.loadingIncome = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingIncomeId === null
          ? 'Error al registrar el ingreso'
          : 'Error al actualizar el ingreso';
        this.loadingIncome = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditAsset(asset: any) {
    this.editingAssetId = asset.id;
    this.newAsset = {
      name: asset.name ?? '',
      value: asset.value ?? 0,
      owner: asset.owner ?? '',
      description: asset.description ?? '',
      purchase_date: asset.purchase_date ?? new Date().toISOString().split('T')[0]
    };
  }

  onDeleteAsset(asset: any) {
    if (!confirm(`¿Deseas eliminar el bien "${asset.name}"?`)) {
      return;
    }

    this.apiService.deleteAsset(asset.id).subscribe({
      next: () => {
        if (this.editingAssetId === asset.id) {
          this.resetAssetForm();
        }
        this.successMsg = 'Bien eliminado correctamente';
        this.loadData();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al eliminar el bien';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditIncome(income: any) {
    this.editingIncomeId = income.id;
    this.newIncome = {
      amount: income.amount ?? 0,
      source: income.source ?? '',
      income_date: income.income_date ?? new Date().toISOString().split('T')[0],
      description: income.description ?? ''
    };
  }

  onDeleteIncome(income: any) {
    if (!confirm(`¿Deseas eliminar el ingreso de "${income.source}"?`)) {
      return;
    }

    this.apiService.deleteIncome(income.id).subscribe({
      next: () => {
        if (this.editingIncomeId === income.id) {
          this.resetIncomeForm();
        }
        this.successMsg = 'Ingreso eliminado correctamente';
        this.loadData();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al eliminar el ingreso';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  resetAssetForm() {
    this.editingAssetId = null;
    this.newAsset = {
      name: '',
      value: 0,
      owner: '',
      description: '',
      purchase_date: new Date().toISOString().split('T')[0]
    };
  }

  resetIncomeForm() {
    this.editingIncomeId = null;
    this.newIncome = {
      amount: 0,
      source: '',
      income_date: new Date().toISOString().split('T')[0],
      description: ''
    };
  }

  getTotalAssetsValue(): number {
    return this.assets.reduce((acc, curr) => acc + curr.value, 0);
  }
}
